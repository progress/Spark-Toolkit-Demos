/*------------------------------------------------------------------------
    File        : OEMetrics
    Purpose     : Gather and report OE metrics for the current PAS instance 
    Description : 
    Author(s)   : Dustin Grau (dugrau@progress.com)
    Created     : Wed Apr 25 13:58:59 EDT 2018
    Notes       : Provides front-end methods to enable/disable features
  ----------------------------------------------------------------------*/

using Progress.Lang.* from propath.
using Progress.Json.ObjectModel.* from propath.
using OpenEdge.Core.Assert from propath.
using OpenEdge.Core.Collections.StringKeyedMap from propath.
using OpenEdge.Logging.* from propath.
using Spark.Core.Util.ABLObjectsReport from propath.

block-level on error undo, throw.

class Spark.Core.Util.OEMetrics inherits Spark.Core.Util.Logger use-widget-pool: 

    /*** Static Instance ***/

    define public static property Instance as Spark.Core.Util.OEMetrics no-undo
        get():
            if not valid-object(Instance) then
                assign Instance = new Spark.Core.Util.OEMetrics().
            return Instance.
        end get.
        private set.

    /*** Common Properties ***/

    define protected property CatalinaBase as character no-undo initial ""
        get():
            if CatalinaBase eq "" then do:
                file-info:filename = trim(os-getenv("CATALINA_BASE")).
                assign CatalinaBase = right-trim(replace(file-info:full-pathname, "~\", "~/"), "~/").
            end.
            return CatalinaBase.
        end get.
        private set.

    define protected property MetricsConfig as character no-undo initial ""
        get():
            if MetricsConfig eq "" then do:
                define variable cConfigName as character no-undo.
                assign cConfigName = trim(os-getenv("METRICS_CONFIG")).
                oLogger:Info(substitute("Metrics Config Name: &1", cConfigName)).

                /* First, check the CATALINA_BASE/conf/ location. */
                file-info:filename = substitute("&1/conf/&2", CatalinaBase, cConfigName).
                if file-info:full-pathname eq ? then do:
                    /* Next, check the CATALINA_BASE/temp/ location. */
                    file-info:filename = substitute("&1/temp/&2", CatalinaBase, cConfigName).
                    if file-info:full-pathname eq ? then do:
                        /* Next, check the CATALINA_BASE/bin/ location. */
                        file-info:filename = substitute("&1/bin/&2", CatalinaBase, cConfigName).
                    end. /* not found in /temp/ */                        
                end. /* not found in /conf/ */

                /* If one of the above paths is still present, use that. */
                if file-info:full-pathname ne ? then
                    assign MetricsConfig = file-info:full-pathname.
                else
                    assign MetricsConfig = "". /* Keep blank if not found. */

                /* Provide context as to where we are getting our config options. */
                oLogger:Info(substitute("Metrics Config Path: &1", MetricsConfig)).
            end. /* MetricsConfig eq "" */

            return MetricsConfig.
        end get.
        private set.

    define protected property RequestCount as integer no-undo initial 0
        get. private set.

    define protected property RequestStart as datetime-tz no-undo initial ?
        get. private set.

    define protected property MetricsEnabled as logical no-undo initial false
        get. private set.

    define protected property ProfilerFilter as character no-undo initial ""
        get. private set.

    define protected property ProfilerThreshold as integer no-undo initial 0
        get. private set.

    define protected property ObjectsSource as character no-undo initial "oejmx"
        get. private set.

    define protected property oABLObjectsReport as ABLObjectsReport no-undo
        get():
            if oABLObjectsReport eq ? or not valid-object(oABLObjectsReport) then
                assign oABLObjectsReport = new ABLObjectsReport(this-object:ObjectsSource).
            return oABLObjectsReport.
        end get.
        private set.

    define protected variable oTrackingMap as StringKeyedMap  no-undo.


    /***** Constructor/Destructor *****/


    constructor public OEMetrics ( ):
        super().

        assign oTrackingMap = new StringKeyedMap().
        this-object:ParseConfig(). /* Obtain configuration options. */
    end constructor.


    destructor public OEMetrics ( ):
        delete object Instance no-error.
        delete object oLogger no-error.
        delete object oTrackingMap no-error.
        delete object oABLObjectsReport no-error.
    end destructor.


    /***** Protected Methods *****/


    method protected void ParseConfig ( ):
        /* Attempt to use any located config file. */
        if (this-object:MetricsConfig gt "") ne true then return.

        define variable oParser as ObjectModelParser no-undo.
        define variable oConfig as JsonObject        no-undo.
        define variable oSubObj as JsonObject        no-undo.
        define variable cNames  as character extent  no-undo.
        define variable ix      as integer           no-undo.

        /* Parse the config file as a JSON object. */
        assign oParser = new ObjectModelParser().
        assign oConfig = cast(oParser:ParseFile(MetricsConfig), JsonObject).

        /* Parse the contents of the JSON object. */
        if valid-object(oConfig) then do:
            assign cNames = oConfig:GetNames().

            /* Set properties based on config options. */
            do ix = 1 to extent(cNames):
                case cNames[ix]:
                    when "enabled" then do:
                        if oConfig:Has("enabled") and oConfig:GetType("enabled") eq JsonDataType:Boolean then
                            assign this-object:MetricsEnabled = oConfig:GetLogical("enabled").
                    end. /* enabled */

                    when "objects" then do:
                        if oConfig:Has("objects") and oConfig:GetType("objects") eq JsonDataType:Object then do:
                            assign oSubObj = oConfig:GetJsonObject("objects").

                            if oSubObj:Has("source") and oSubObj:GetType("source") eq JsonDataType:String then
                                assign this-object:ObjectsSource = oSubObj:GetCharacter("source").

                            delete object oSubObj no-error.
                        end. /* has sub-object */
                    end. /* objects */

                    when "profiler" then do:
                        if oConfig:Has("profiler") and oConfig:GetType("profiler") eq JsonDataType:Object then do:
                            assign oSubObj = oConfig:GetJsonObject("profiler").

                            if oSubObj:Has("filter") and oSubObj:GetType("filter") eq JsonDataType:String then
                                assign this-object:ProfilerFilter = oSubObj:GetCharacter("filter").

                            if oSubObj:Has("threshold") and oSubObj:GetType("threshold") eq JsonDataType:Number then
                                assign this-object:ProfilerThreshold = oSubObj:GetInteger("threshold").

                            delete object oSubObj no-error.
                        end. /* has sub-object */
                    end. /* profiler */
                end case. /* cNames */
            end. /* do ix */
        end. /* valid object */

        catch err as Progress.Lang.Error:
            oLogger:Error(substitute("Error parsing config file: &1", err:GetMessage(1))).
            undo, throw err.                
        end catch.
        finally:
            delete object oParser no-error.
            delete object oConfig no-error.
        end finally.
    end method. /* ParseConfig */


    method protected OERequestInfo GetRequestInfo ( ):
        return cast(session:current-request-info, OERequestInfo).
    end method. /* GetRequestInfo */


    method protected integer GetAgentID ( ):
        define variable oRequestInfo as OERequestInfo no-undo.

        assign oRequestInfo = cast(session:current-request-info, OERequestInfo).
        if valid-object(oRequestInfo) then
            return oRequestInfo:AgentId.

        return ?.

        finally:
            delete object oRequestInfo no-error.
        end finally.
    end method. /* GetAgentID */


    method protected integer GetSessionID ( ):
        define variable oRequestInfo as OERequestInfo no-undo.

        assign oRequestInfo = cast(session:current-request-info, OERequestInfo).
        if valid-object(oRequestInfo) then
            return oRequestInfo:SessionId.

        return ?.

        finally:
            delete object oRequestInfo no-error.
        end finally.
    end method. /* GetSessionID */


    /***** Public Methods *****/


    method public logical StartProfiler ( ):
        /* Start the profiler with any config-set filtering. */
        if (this-object:ProfilerFilter gt "") eq true then
            return this-object:StartProfiler(this-object:ProfilerFilter).
        else
            return this-object:StartProfiler("*"). /* No filter. */
    end method. /* StartProfiler */


    method public logical StartProfiler ( input pcFilter as character ):
        /**
         * Method is created as static to allow starting of a profiler session
         * without need for a class instance. This makes it useful for starting
         * within a session activate procedure, while the writing of the report
         * can be done within a deactivate procedure. Therefore, this method can
         * have no other dependencies or requirements of a class-instance method.
         */

        if not this-object:MetricsEnabled then do:
            oLogger:Info("Metrics disabled, leaving StartProfiler").
            return false.
        end. /* not enabled */

        define variable oRequestInfo as OERequestInfo no-undo.
        define variable lFilterMatch as logical       no-undo initial false.
        define variable cOutPath     as character     no-undo.
        define variable ix           as integer       no-undo.

        /* Obtain the request information and set/increment special values. */
        assign oRequestInfo = cast(session:current-request-info, OERequestInfo).
        assign this-object:RequestCount = this-object:RequestCount + 1.
        assign this-object:RequestStart = now.
        
        /* Filter should not be blank, so fill with wildcard at least. */
        if (pcFilter gt "") ne true then assign pcFilter = "*".

        /* Check if requested procedure is matches in the filter list. */
        do ix = 1 to num-entries(pcFilter):
            if oRequestInfo:ProcedureName matches entry(ix, pcFilter) then
                assign lFilterMatch = true.
        end. /* do ix */

        if lFilterMatch then do:
            /* Determine correct output location for this profiler log. */
            assign cOutPath = right-trim(replace(session:temp-directory, "~\", "~/"), "~/").
            assign cOutPath = substitute("&1/Profiler_&2_&3_&4.prof",
                                         cOutPath, this-object:RequestCount, oRequestInfo:AgentId, oRequestInfo:SessionId).

            assign /* Note: Order matters here, do not rearrange! */
                profiler:enabled      = true
                profiler:profiling    = true
                profiler:file-name    = cOutPath
                profiler:description  = "Profiler Output"
                profiler:trace-filter = "*":u
                profiler:tracing      = "":u
                profiler:coverage     = true
                profiler:statistics   = true
                .

            return true.
        end. /* matches */

        return false. /* No filter matched for profiling. */

        catch err as Progress.Lang.Error:
            /* Should fail silently, while delivering errors to the standard local. */
            oLogger:Error(substitute("Error starting profiler: &1", err:GetMessage(1))).
            return false.
        end catch.
    end method. /* StartProfiler */


    method public logical WriteProfiler ( ):
        /* Start the profiler with any config-set filtering. */
        if this-object:ProfilerThreshold gt 0 then
            return this-object:WriteProfiler(this-object:ProfilerThreshold).
        else
            return this-object:WriteProfiler(0). /* No threshold. */
    end method. /* StartProfiler */


    method public logical WriteProfiler ( input piMinExecTime as integer ):
        /**
         * Method is created as static to allow profiler output to be generated at
         * any time in the request lifecycle without dependency on a class instance.
         * Output beyond the profiler data itself should be performed via the new
         * LogWriter feature to place information/errors into a dedicated log file.
         * This allows for additional context about a request to be logged without
         * generating a standalone file, whether the profiler output has been made
         * available or not (eg. excution time may always be reported).
         */

        if not this-object:MetricsEnabled then do:
            oLogger:Info("Metrics disabled, leaving WriteProfiler").
            return false.
        end. /* not enabled */

        define variable oRequestInfo as OERequestInfo no-undo.
        define variable oProfLogger  as ILogWriter    no-undo.
        define variable iExecTime    as integer       no-undo initial 0.

        /* Configure the logger and obtain the request information. */
        assign oProfLogger = LoggerBuilder:GetLogger("Spark.Core.Util.OEMetrics").
        assign oRequestInfo = cast(session:current-request-info, OERequestInfo).

        /* Determine the time elapsed for this request. */
        if this-object:RequestStart ne ? and this-object:RequestStart lt now then
            assign iExecTime = interval(now, this-object:RequestStart, "milliseconds" ).

        if profiler:enabled then do:
            /* Turn off the profiler, if previously enabled. */
            assign
                profiler:profiling = false
                profiler:enabled   = false
                .

            /* Only write the data out if execution time exceeds threshold. */
            if piMinExecTime eq ? or piMinExecTime lt 0 then assign piMinExecTime = 0.
            if iExecTime gt piMinExecTime then do:
                oProfLogger:Info(substitute("&1 | &2ms | &3",
                                            oRequestInfo:ProcedureName, iExecTime, profiler:file-name)).
                profiler:write-data().
            end. /* iExecTime gt piMinExecTime */
            else
                oProfLogger:Info(substitute("&1 | &2ms | -No Profiler Output-",
                                            oRequestInfo:ProcedureName, iExecTime)).

            return true.
        end. /* profiler:enabled */
        else
            oProfLogger:Info(substitute("&1 | &2ms | -Profiler Disabled-",
                                        oRequestInfo:ProcedureName, iExecTime)).

        return false. /* Profiler not enabled. */

        catch err as Progress.Lang.Error:
            /* Should fail silently, while delivering errors to the standard local. */
            oLogger:Error(substitute("Error writing profiler: &1", err:GetMessage(1))).
            return false.
        end catch.
        finally:
            delete object oProfLogger no-error.
        end finally.
    end method. /* WriteProfiler */


    method public logical StartTrackingObjects ( ):
        define variable iAgentID    as integer no-undo.
        define variable lIsTracking as logical no-undo initial false.

        assign iAgentID = this-object:GetAgentID(). /* Obtain the current AgentID. */

        /* Avoid making the call to the agent if we have previously marked this agent as tracking objects. */
message iAgentID ":" oTrackingMap:ContainsKey(string(iAgentID)).
        if oTrackingMap:ContainsKey(string(iAgentID)) then
            assign lIsTracking = cast(oTrackingMap:Get(string(iAgentID)), OpenEdge.Core.LogicalValue):Value.
        else
            assign lIsTracking = oABLObjectsReport:TrackingABLObjects(string(iAgentID)).

        if not lIsTracking then /* Turn on tracking if not already, and get latest result. */
            assign lIsTracking = oABLObjectsReport:TrackABLObjects(string(iAgentID), true).

        /* Remember whether objects are being tracked for this agent. */
        if lIsTracking and not oTrackingMap:ContainsKey(string(iAgentID)) then
            oTrackingMap:Put(string(iAgentID), new OpenEdge.Core.LogicalValue(lIsTracking)).

        return lIsTracking.
    end method. /* StartTrackingObjects */


    method public logical GetABLObjectsReport ( ):
        define variable iAgentID    as integer   no-undo.
        define variable lIsTracking as logical   no-undo initial false.
        define variable oObjReport  as JsonArray no-undo.

        assign iAgentID = this-object:GetAgentID(). /* Obtain the current AgentID. */

        /* If tracking is enabled, obtain the latest ABLObjects report from the agent. */
        assign lIsTracking = oABLObjectsReport:TrackingABLObjects(string(iAgentID)).
        if lIsTracking then
            assign oObjReport = oABLObjectsReport:ParseABLObjectReport(string(iAgentID)).

        /* Output the report to a known location on disk for review/archival. */
        if valid-object(oObjReport) then
            return oObjReport:WriteFile(substitute("&1/ABLObjectsReport-&2-&3-&4.json",
                                                   right-trim(replace(session:temp-directory, "~\", "~/"), "~/"),
                                                   iso-date(today), mtime, iAgentID), true).

        return false. /* Result for fall-through. */

        finally:
            delete object oObjReport no-error.
        end finally.
    end method. /* GetABLObjectsReport */


    method public logical TestABLObjectsReport ( ):
        /**
         * Trigger an all-in-one test case of the ABLObjectsReport by enabling
         * tracking of objects, report gathered data, and stop tracking. For
         * real-world use these actions should be performed at distinct times
         * within the application and only when necessary.
         */

        if not this-object:MetricsEnabled then do:
            oLogger:Info("Metrics disabled, leaving TestABLObjectsReport").
            return false.
        end. /* not enabled */

        /* Prime the pump by getting a list of agents for this PAS instance. */
        oABLObjectsReport:getAgents().

        /* Set up tracking of the ABL Objects, gather a report, and turn off tracking. */
        define variable oReport as JsonObject no-undo.
        if oABLObjectsReport:TrackABLObjects(true) then do:
            assign oReport = oABLObjectsReport:ParseABLObjectReport().
            if valid-object(oReport) then
                oReport:WriteFile(substitute("&1/ABLObjectsReport-&2-&3.json",
                                             right-trim(replace(session:temp-directory, "~\", "~/"), "~/"),
                                             iso-date(today), mtime), true).
            return valid-object(oReport).
        end. /* tracking enabled */
        else
            undo, throw new AppError("Unable to enable ABLObjects tracking.", 0).

        return false.

        catch err as Progress.Lang.Error:
            /* Should fail silently, while delivering errors to the standard local. */
            oLogger:Error(substitute("Error testing ABLObjects: &1", err:GetMessage(1))).
            return false.
        end catch.
        finally:
            /* Always attempt to disable tracking for this particular test. */
            if valid-object(oABLObjectsReport) then
                oABLObjectsReport:TrackABLObjects(false).
            delete object oReport no-error.
        end finally.
    end method. /* GetABLObjectsReport */

end class.
