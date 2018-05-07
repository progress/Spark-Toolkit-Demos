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
using OpenEdge.Logging.* from propath.
using Spark.Diagnostic.Util.ABLObjectsReport from propath.
using Spark.Diagnostic.Util.OEMetrics from propath.

block-level on error undo, throw.

class Spark.Diagnostic.Util.OEMetrics inherits Spark.Diagnostic.Util.Logger use-widget-pool final: 

    /*** Static Instance ***/

    define public static property Instance as Spark.Diagnostic.Util.OEMetrics no-undo
        get():
            if not valid-object(Instance) then
                assign Instance = new Spark.Diagnostic.Util.OEMetrics().
            return Instance.
        end get.
        private set.

    /*** Common Properties ***/

    define private property CatalinaBase as character no-undo initial ""
        get():
            if CatalinaBase eq "" then do:
                file-info:filename = trim(os-getenv("CATALINA_BASE")).
                assign CatalinaBase = right-trim(replace(file-info:full-pathname, "~\", "~/"), "~/").
            end.
            return CatalinaBase.
        end get.
        set.

    define private property TemporaryDir as character no-undo initial ""
        get():
            if TemporaryDir eq "" then
                assign TemporaryDir = right-trim(replace(session:temp-directory, "~\", "~/"), "~/").
            return TemporaryDir.
        end get.
        set.

    define private property MetricsStarted as datetime no-undo initial ? get. set.

    define private property MetricsConfigLoaded as datetime no-undo initial ? get. set.

    define private property MetricsConfigPath as character no-undo initial ""
        get():
            if MetricsConfigPath eq "" then do:
                /* Determine the location of the config file for this feature. */
                define variable cConfigName as character no-undo.
                assign cConfigName = trim(os-getenv("METRICS_CONFIG")).
                oLogger:Trace(substitute("Metrics Config Name: &1", cConfigName)).

                /* First, check the CATALINA_BASE/conf/ location. */
                file-info:filename = substitute("&1/conf/&2", this-object:CatalinaBase, cConfigName).
                if file-info:full-pathname eq ? then do:
                    /* Next, check the CATALINA_BASE/bin/ location. */
                    file-info:filename = substitute("&1/bin/&2", this-object:CatalinaBase, cConfigName).
                    if file-info:full-pathname eq ? then do:
                        /* Last, check the SESSION-TEMP location. */
                        file-info:filename = substitute("&1/&2", this-object:TemporaryDir, cConfigName).
                    end. /* not found in /bin/ */                        
                end. /* not found in /conf/ */

                /* If one of the above paths is still present, use that. */
                if file-info:full-pathname ne ? then
                    assign MetricsConfigPath = file-info:full-pathname.
                else
                    assign MetricsConfigPath = "". /* Keep blank if not found. */

                /* Provide context as to where we are getting our config options. */
                oLogger:Info(substitute("Metrics Config Path: &1", MetricsConfigPath)).
            end. /* MetricsConfigPath eq "" */

            return MetricsConfigPath.
        end get.
        set.

    define private property MetricsIgnoreList as character no-undo initial "" get. set.

    define private property RequestCount as integer no-undo initial 0 get. set.

    define private property RequestStart as datetime-tz no-undo initial ? get. set.

    define private property ProfilerEnabled as logical no-undo initial false get. set.

    define private property ProfilerFilter as character no-undo initial "" get. set.

    define private property ProfilerThreshold as integer no-undo initial 0 get. set.

    define private property ObjectsEnabled as logical no-undo initial false get. set.

    define private property ObjectsExcluded as character no-undo initial "" get. set.

    define private property ObjectsSource as character no-undo initial "oejmx" get. set.

    define private property oABLObjectsReport as ABLObjectsReport no-undo
        get():
            if oABLObjectsReport eq ? or not valid-object(oABLObjectsReport) then
                assign oABLObjectsReport = new ABLObjectsReport(this-object:ObjectsSource).
            return oABLObjectsReport.
        end get.
        set.

    define private property AgentDataPath as character no-undo initial ""
        get():
            if AgentDataPath eq "" then
                assign AgentDataPath = substitute("&1/agents.json", this-object:TemporaryDir).
            return AgentDataPath.
        end get.
        set.


    /***** Constructor/Destructor *****/


    constructor public OEMetrics ( ):
        super().

        assign this-object:MetricsStarted = now. /* Note when class was created. */
        this-object:CheckTempPath(). /* Check for temporary directories. */
        this-object:CheckConfig(). /* Obtain configuration options. */
    end constructor.


    destructor OEMetrics ( ):
        delete object Instance no-error.
        delete object oLogger no-error.
        delete object oABLObjectsReport no-error.
    end destructor.


    /***** Protected Methods *****/


    method private void CheckTempPath ( ):
        define variable cTempPath as character no-undo.

        /* Make sure we have a consistent path for temporary files. */
        os-create-dir value(substitute("&1", this-object:TemporaryDir)).
        os-create-dir value(substitute("&1/metrics", this-object:TemporaryDir)).

        /* Make sure any necessary directories are created. */
        os-create-dir value(substitute("&1/metrics/ABLObjectsReport", this-object:TemporaryDir)).
        os-create-dir value(substitute("&1/metrics/ProfilerData", this-object:TemporaryDir)).
    end method. /* CheckTempPath */


    method private void CheckConfig ( ):
        /* Cannot proceed if the configuration file is not present. */
        if (this-object:MetricsConfigPath gt "") ne true then return.

        /* Load the config file path as previously discovered. */
        file-info:file-name = this-object:MetricsConfigPath.
        if file-info:full-pathname ne ? then do:
            define variable dLastDate as datetime no-undo.

            /* Get the current date/time . */
            assign dLastDate = datetime(file-info:file-mod-date, file-info:file-mod-time * 1000).

            if dLastDate ne this-object:MetricsConfigLoaded then do:
                oLogger:Debug("Updating configuration options from file.").

                /* Mark down the current modified date/time for this file. */
                assign MetricsConfigLoaded = dLastDate.

                /* Load and parse the current config file. */
                this-object:ParseConfig().
            end. /* File Changed */
        end. /* File Exists */
    end method. /* CheckConfig */


    method private void ParseConfig ( ):
        /* Cannot proceed if the configuration file is not present. */
        if (this-object:MetricsConfigPath gt "") ne true then return.

        define variable oParser as ObjectModelParser no-undo.
        define variable oConfig as JsonObject        no-undo.
        define variable oSubObj as JsonObject        no-undo.
        define variable cNames  as character extent  no-undo.
        define variable ix      as integer           no-undo.

        /* Parse the config file as a JSON object. */
        assign oParser = new ObjectModelParser().
        assign oConfig = cast(oParser:ParseFile(MetricsConfigPath), JsonObject).

        /* Parse the contents of the JSON object. */
        if valid-object(oConfig) then do:
            assign cNames = oConfig:GetNames().

            /* Set properties based on config options. */
            do ix = 1 to extent(cNames):
                case cNames[ix]:
                    when "general" then do:
                        if oConfig:Has("general") and oConfig:GetType("general") eq JsonDataType:Object then do:
                            assign oSubObj = oConfig:GetJsonObject("general").

                            if oSubObj:Has("ignore") and oSubObj:GetType("ignore") eq JsonDataType:String then
                                assign this-object:MetricsIgnoreList = oSubObj:GetCharacter("ignore").

                            delete object oSubObj no-error.
                        end. /* has sub-object */
                    end. /* general */

                    when "objects" then do:
                        if oConfig:Has("objects") and oConfig:GetType("objects") eq JsonDataType:Object then do:
                            assign oSubObj = oConfig:GetJsonObject("objects").

                            if oSubObj:Has("enabled") and oSubObj:GetType("enabled") eq JsonDataType:Boolean then
                                assign this-object:ObjectsEnabled = oSubObj:GetLogical("enabled").

                            if oSubObj:Has("exclude") and oSubObj:GetType("exclude") eq JsonDataType:String then
                                assign this-object:ObjectsExcluded = oSubObj:GetCharacter("exclude").

                            if oSubObj:Has("source") and oSubObj:GetType("source") eq JsonDataType:String then
                                assign this-object:ObjectsSource = oSubObj:GetCharacter("source").

                            delete object oSubObj no-error.
                        end. /* has sub-object */
                    end. /* objects */

                    when "profiler" then do:
                        if oConfig:Has("profiler") and oConfig:GetType("profiler") eq JsonDataType:Object then do:
                            assign oSubObj = oConfig:GetJsonObject("profiler").

                            if oSubObj:Has("enabled") and oSubObj:GetType("enabled") eq JsonDataType:Boolean then
                                assign this-object:ProfilerEnabled = oSubObj:GetLogical("enabled").

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


    method private logical InMatchList ( input pcCompare as character,
                                         input pcMatches as character ):
        /* Check if value matches something in the list. */
        define variable ix as integer no-undo.
        do ix = 1 to num-entries(pcMatches):
            if pcCompare matches entry(ix, pcMatches) then
                return true.
        end. /* do ix */

        return false.
    end method. /* InMatchList */
    

    method private OERequestInfo GetRequestInfo ( ):
        return cast(session:current-request-info, OERequestInfo).
    end method. /* GetRequestInfo */


    method private character GetProcedureName ( ):
        define variable oRequestInfo as OERequestInfo no-undo.

        assign oRequestInfo = this-object:GetRequestInfo().
        if valid-object(oRequestInfo) then
            return oRequestInfo:ProcedureName.

        return "".

        finally:
            delete object oRequestInfo no-error.
        end finally.
    end method. /* GetProcedureName */


    method private integer GetAgentID ( ):
        define variable oRequestInfo as OERequestInfo no-undo.

        assign oRequestInfo = this-object:GetRequestInfo().
        if valid-object(oRequestInfo) then
            return oRequestInfo:AgentId.

        return ?.

        finally:
            delete object oRequestInfo no-error.
        end finally.
    end method. /* GetAgentID */


    method private integer GetSessionID ( ):
        define variable oRequestInfo as OERequestInfo no-undo.

        assign oRequestInfo = this-object:GetRequestInfo().
        if valid-object(oRequestInfo) then
            return oRequestInfo:SessionId.

        return ?.

        finally:
            delete object oRequestInfo no-error.
        end finally.
    end method. /* GetSessionID */


    method private character GetTrackingFlag ( input piAgentID as integer ):
        os-create-dir value(substitute("&1/metrics", this-object:TemporaryDir)).
        os-create-dir value(substitute("&1/metrics/TrackingAgents", this-object:TemporaryDir)).

        return substitute("&1/metrics/TrackingAgents/&2", this-object:TemporaryDir, piAgentID).
    end method. /* GetTrackingFlag */


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

        this-object:CheckConfig(). /* Update configuration options. */

        if not this-object:ProfilerEnabled then do:
            oLogger:Debug("Profiler disabled, leaving StartProfiler").
            return false.
        end. /* not enabled */

        define variable oRequestInfo as OERequestInfo no-undo.
        define variable lFilterMatch as logical       no-undo initial false.
        define variable cBasePath    as character     no-undo.
        define variable cOutPath     as character     no-undo.
        define variable ix           as integer       no-undo.

        /* Obtain the request information and set/increment special values. */
        assign oRequestInfo = this-object:GetRequestInfo().
        assign this-object:RequestCount = this-object:RequestCount + 1.
        assign this-object:RequestStart = now.
        
        /* Filter should not be blank, so fill with wildcard at least. */
        if (pcFilter gt "") ne true then assign pcFilter = "*".

        /* Check if requested procedure matches in the filter whitelist. */
        if this-object:InMatchList(oRequestInfo:ProcedureName, pcFilter) then do:
            /* Create base path for output and create any needed directories. */
            assign cBasePath = substitute("&1/metrics/ProfilerData/&2", this-object:TemporaryDir, oRequestInfo:AgentId).
            os-create-dir value(cBasePath) no-error.

            /* Determine correct output location for this profiler log. */
            assign cOutPath = substitute("&1/&2.&3_R&4_A&5_S&6.prof",
                                         cBasePath, replace(iso-date(today), "-", ""), mtime, this-object:RequestCount,
                                         oRequestInfo:AgentId, oRequestInfo:SessionId).

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
        finally:
            delete object oRequestInfo no-error.
        end finally.
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

        if not this-object:ProfilerEnabled then do:
            oLogger:Debug("Profiler disabled, leaving WriteProfiler").

            /* Even if profiling has been disabled, make sure we turn it off. */
            if profiler:enabled then            
                assign
                    profiler:profiling = false
                    profiler:enabled   = false
                    .

            return false.
        end. /* not enabled */

        define variable oRequestInfo as OERequestInfo no-undo.
        define variable iExecTime    as integer       no-undo initial 0.

        /* Configure the logger and obtain the request information. */
        assign oRequestInfo = this-object:GetRequestInfo().

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
                oLogger:Info(substitute("&1 | &2ms | &3",
                                        oRequestInfo:ProcedureName, iExecTime, profiler:file-name)).
                profiler:write-data().
            end. /* iExecTime gt piMinExecTime */
            else
                oLogger:Info(substitute("&1 | &2ms | -No Profiler Output-",
                                        oRequestInfo:ProcedureName, iExecTime)).

            return true.
        end. /* profiler:enabled */
        else
            oLogger:Info(substitute("&1 | &2ms | -Profiler Disabled-",
                                    oRequestInfo:ProcedureName, iExecTime)).

        return false. /* Profiler not enabled. */

        catch err as Progress.Lang.Error:
            /* Should fail silently, while delivering errors to the standard local. */
            oLogger:Error(substitute("Error writing profiler: &1", err:GetMessage(1))).
            return false.
        end catch.
        finally:
            delete object oRequestInfo no-error.
        end finally.
    end method. /* WriteProfiler */


    method public logical StartTrackingObjects ( ):
        define variable iAgentID    as integer   no-undo.
        define variable cProcedure  as character no-undo.
        define variable cTrackFlag  as character no-undo.
        define variable lIsTracking as logical   no-undo initial false.

        this-object:CheckConfig(). /* Update configuration options. */

        if not this-object:ObjectsEnabled then do:
            oLogger:Debug("Objects disabled, leaving StartTrackingObjects").
            return false.
        end. /* not enabled */

        assign cProcedure = this-object:GetProcedureName().
        if this-object:MetricsIgnoreList ne "" then do:
            /* Do not proceed if current request procedure is on the ignore list. */
            if this-object:InMatchList(cProcedure, this-object:MetricsIgnoreList) then do:
                oLogger:Debug(substitute("Procedure skipped due to ignore list: &1", cProcedure)).
                return false.
            end. /* ignored */
        end. /* has ignore list */

        assign iAgentID = this-object:GetAgentID(). /* Obtain the current AgentID. */

        /* Avoid making the call to the agent if we have previously marked this agent as tracking objects. */
        assign cTrackFlag = this-object:GetTrackingFlag(iAgentID).
        file-info:file-name = cTrackFlag.
        if file-info:full-pathname ne ? then do:
            /* Make sure flag was created AFTER the agent started this class instance. */
            if datetime(file-info:file-create-date, file-info:file-create-time * 1000) lt this-object:MetricsStarted then
                os-delete value(file-info:full-pathname). /* Remove the tracking flag. */
            else
                assign lIsTracking = true. /* Flag exists, assume tracking is enabled. */
        end. /* file exists */

        if not lIsTracking then /* Not obviously tracked, set up option for agent. */
            assign lIsTracking = oABLObjectsReport:TrackingABLObjects(string(iAgentID)).

        if not lIsTracking then /* Turn on tracking if not already, and get latest result. */
            assign lIsTracking = oABLObjectsReport:TrackABLObjects(string(iAgentID), true).

        /* Remember whether objects are being tracked for this agent. */
        if lIsTracking then do:
            output to value(cTrackFlag).
            output close.
        end. /* Tracking */

        return lIsTracking.
    end method. /* StartTrackingObjects */


    method public logical StopTrackingObjects ( ):
        define variable iAgentID as integer no-undo.

        if not this-object:ObjectsEnabled then do:
            oLogger:Debug("Objects disabled, leaving StopTrackingObjects").
            return false.
        end. /* not enabled */

        assign iAgentID = this-object:GetAgentID(). /* Obtain the current AgentID. */

        /* Just immediately disable the object tracking for this agent. */
        return oABLObjectsReport:TrackABLObjects(string(iAgentID), false).
    end method. /* StopTrackingObjects */
    

    method public logical GetABLObjectsReport ( ):
        define variable iAgentID    as integer    no-undo.
        define variable iCount      as integer    no-undo.
        define variable cProcedure  as character  no-undo.
        define variable cSessionID  as character  no-undo extent.
        define variable cBasePath   as character  no-undo.
        define variable lIsTracking as logical    no-undo initial false.
        define variable lReturn     as logical    no-undo initial false.
        define variable oObjReport  as JsonObject no-undo.

        this-object:CheckConfig(). /* Update configuration options. */

        if not this-object:ObjectsEnabled then do:
            oLogger:Debug("Objects disabled, leaving GetABLObjectsReport").
            return false.
        end. /* not enabled */

        assign cProcedure = this-object:GetProcedureName().
        if this-object:MetricsIgnoreList ne "" then do:
            /* Do not proceed if current request procedure is on the ignore list. */
            if this-object:InMatchList(cProcedure, this-object:MetricsIgnoreList) then do:
                oLogger:Debug(substitute("Procedure skipped due to ignore list: &1", cProcedure)).
                return false.
            end. /* ignored */
        end. /* has ignore list */

        assign iAgentID = this-object:GetAgentID(). /* Obtain the current AgentID. */

        /* Assemble base path for output and create any needed directories. */
        assign cBasePath = substitute("&1/metrics/ABLObjectsReport/&2", this-object:TemporaryDir, iAgentID).
        os-create-dir value(cBasePath) no-error.

        /* If tracking is enabled, obtain the latest ABLObjects report from the agent. */
        assign lIsTracking = oABLObjectsReport:TrackingABLObjects(string(iAgentID)).
        if lIsTracking then do:
            if oABLObjectsReport:ParseABLObjectReport(input  iAgentID,
                                                      input  this-object:ObjectsExcluded,
                                                      output oObjReport) then do:
                /* Output a file for each session in report. */
                assign cSessionID = oObjReport:GetNames().
                do iCount = 1 to extent(cSessionID):
                    /* Output the report to a known location on disk for review/archival. */
                    oObjReport:GetJsonArray(cSessionID[iCount])
                              :WriteFile(substitute("&1/&2.&3_A&4_S&5.json",
                                                    cBasePath,
                                                    replace(iso-date(today), "-", ""),
                                                    mtime, iAgentID, cSessionID[iCount]), true).
                end. /* do iCount */

                assign lReturn = true.
            end. /* ParseABLObjectReport */
        end. /* lIsTracking */

        return lReturn.

        finally:
            delete object oObjReport no-error.
        end finally.
    end method. /* GetABLObjectsReport */


    method public logical TrackAllObjects ( input plEnable as logical ):
        define variable oAgent   as JsonObject no-undo.
        define variable cAgentID as character  no-undo.
        define variable iCount   as integer    no-undo.
        define variable lSuccess as logical    no-undo initial false.

        /* Get the agents if object is not present. */
        if not valid-object(ABLObjectsReport:AgentList) then oABLObjectsReport:GetAgents().

        /* Make request to all agents of this ABLApp. */
        do iCount = 1 to ABLObjectsReport:AgentList:Length:
            /* Set request with PAS instance name and specific Agent ID. */
            assign oAgent = ABLObjectsReport:AgentList:GetJsonObject(iCount).
            if valid-object(oAgent) and oAgent:Has("pid") then do:
                /* Set the tracking option for this agent. */
                assign cAgentID = oAgent:GetCharacter("pid").
                if oABLObjectsReport:TrackABLObjects(cAgentID, plEnable) then
                    assign lSuccess = true.
            end. /* has agentId */
        end. /* do iCount */

        return lSuccess.
    end method. /* TrackABLObjects */


    method public logical GetAllABLObjectsReport ( ):
        define variable oObjReport as JsonObject no-undo.
        define variable oAgent     as JsonObject no-undo.
        define variable cAgentID   as character  no-undo.
        define variable cSessionID as character  no-undo extent.
        define variable cBasePath  as character  no-undo.
        define variable iCount     as integer    no-undo.
        define variable lReturn    as logical    no-undo initial false.

        this-object:CheckConfig(). /* Update configuration options. */

        if not this-object:ObjectsEnabled then do:
            oLogger:Debug("Objects disabled, leaving GetAllABLObjectsReport").
            return false.
        end. /* not enabled */

        /* Get the agents if object is not present. */
        if not valid-object(ABLObjectsReport:AgentList) then oABLObjectsReport:GetAgents().

        /* Make request to all agents of this ABLApp. */
        do iCount = 1 to ABLObjectsReport:AgentList:Length:
            /* Set request with PAS instance name and specific Agent ID. */
            assign oAgent = ABLObjectsReport:AgentList:GetJsonObject(iCount).
            if oAgent:Has("pid") then
            do on error undo, throw:
                /* Extract the current agent for examination. */
                assign cAgentID = oAgent:GetCharacter("pid").

                /* Assemble base path for output and create any needed directories. */
                assign cBasePath = substitute("&1/metrics/ABLObjectsReport/&2", this-object:TemporaryDir, cAgentID).
                os-create-dir value(cBasePath) no-error.

                /* Request the ABL objects for this specific agent. */
                if oABLObjectsReport:ParseABLObjectReport(input  cAgentID,
                                                          input  this-object:ObjectsExcluded,
                                                          output oObjReport) then do:
                    /* Output a file for each session in report. */
                    assign cSessionID = oObjReport:GetNames().
                    do iCount = 1 to extent(cSessionID):
                        /* Output the report to a known location on disk for review/archival. */
                        oObjReport:GetJsonArray(cSessionID[iCount])
                                  :WriteFile(substitute("&1/&2.&3_A&4_S&5.json",
                                                        cBasePath,
                                                        replace(iso-date(today), "-", ""),
                                                        mtime, cAgentID, cSessionID[iCount]), true).
                    end. /* do iCount */

                    assign lReturn = true.
                end. /* ParseABLObjectReport */
            end. /* has agentId */
        end. /* do iCount */

        return lReturn.

        finally:
            delete object oObjReport no-error.
        end finally.
    end method. /* GetAllABLObjectsReport */


    method public logical GetSessionABLObjectsReport ( ):
        define variable oReport    as JsonArray no-undo.
        define variable iAgentID   as integer   no-undo.
        define variable iSessionID as integer   no-undo.
        define variable cProcedure as character no-undo.
        define variable cBasePath  as character no-undo.
        define variable lReturn    as logical   no-undo initial false.

        this-object:CheckConfig(). /* Update configuration options. */

        if not this-object:ObjectsEnabled then do:
            oLogger:Debug("Objects disabled, leaving GetAllABLObjectsReport").
            return false.
        end. /* not enabled */

        assign cProcedure = this-object:GetProcedureName().
        if this-object:MetricsIgnoreList ne "" then do:
            /* Do not proceed if current request procedure is on the ignore list. */
            if this-object:InMatchList(cProcedure, this-object:MetricsIgnoreList) then do:
                oLogger:Debug(substitute("Procedure skipped due to ignore list: &1", cProcedure)).
                return false.
            end. /* ignored */
        end. /* has ignore list */

        assign
            iAgentID   = this-object:GetAgentID()
            iSessionID = this-object:GetSessionID()
            .

        /* Assemble base path for output and create any needed directories. */
        assign cBasePath = substitute("&1/metrics/ABLObjectsReport/&2", this-object:TemporaryDir, iAgentID).
        os-create-dir value(cBasePath) no-error.

        if iAgentID gt 0 and iSessionID gt 0 then do:
            /* Request the ABL objects for this specific agent and session. */
            if oABLObjectsReport:ParseSessionABLObjectReport(input  iAgentID,
                                                             input  iSessionID,
                                                             input  this-object:ObjectsExcluded,
                                                             output oReport) then
                /* Output the report to a known location on disk for review/archival. */
                oReport:WriteFile(substitute("&1/&2.&3_A&4_S&5.json",
                                             cBasePath,
                                             replace(iso-date(today), "-", ""),
                                             mtime, iAgentID, iSessionID), true).

            assign lReturn = true.
        end. /* Has Agent/Session */

        return lReturn.

        finally:
            delete object oReport no-error.
        end finally.
    end method. /* GetSessionABLObjectsReport */

end class.
