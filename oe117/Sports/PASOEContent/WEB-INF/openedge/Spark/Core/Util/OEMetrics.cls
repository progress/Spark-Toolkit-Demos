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
using OpenEdge.Logging.* from propath.
using Spark.Core.Util.ABLObjectsReport from propath.

block-level on error undo, throw.

class Spark.Core.Util.OEMetrics inherits Spark.Core.Util.Logger use-widget-pool: 

    define public static property RequestCount as integer no-undo initial 0
        get. private set.

    define public static property RequestStart as datetime-tz no-undo initial ?
        get. private set.

    define private variable oABLObjectsReport as ABLObjectsReport no-undo.


    /***** Static Methods *****/


    method public static logical StartProfiler ( input pcFilter as character ):
        /**
         * Method is created as static to allow starting of a profiler session
         * without need for a class instance. This makes it useful for starting
         * within a session activate procedure, while the writing of the report
         * can be done within a deactivate procedure. Therefore, this method can
         * have no other dependencies or requirements of a class-instance method.
         */

        define variable oRequestInfo as OERequestInfo no-undo.
        define variable lFilterMatch as logical       no-undo initial false.
        define variable cOutPath     as character     no-undo.
        define variable ix           as integer       no-undo.

        /* Obtain the request information and set/increment special values. */
        assign oRequestInfo = cast(session:current-request-info, OERequestInfo).
        assign RequestCount = RequestCount + 1.
        assign RequestStart = now.
        
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
                                         cOutPath, RequestCount,
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
            message err:GetMessage(1).
            return false.
        end catch.
    end method. /* StartProfiler */


    method public static logical WriteProfiler ( input piMinExecTime as integer ):
        /**
         * Method is created as static to allow profiler output to be generated at
         * any time in the request lifecycle without dependency on a class instance.
         * Output beyond the profiler data itself should be performed via the new
         * LogWriter feature to place information/errors into a dedicated log file.
         * This allows for additional context about a request to be logged without
         * generating a standalone file, whether the profiler output has been made
         * available or not (eg. excution time may always be reported).
         */

        define variable oRequestInfo as OERequestInfo no-undo.
        define variable oProfLogger  as ILogWriter    no-undo.
        define variable iExecTime    as integer       no-undo initial 0.

        /* Configure the logger and obtain the request information. */
        assign oProfLogger = LoggerBuilder:GetLogger("Spark.Core.Util.OEMetrics").
        assign oRequestInfo = cast(session:current-request-info, OERequestInfo).

        /* Determine the time elapsed for this request. */
        if RequestStart ne ? and RequestStart lt now then
            assign iExecTime = interval(now, RequestStart, "milliseconds" ).

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
            message err:GetMessage(1).
            return false.
        end catch.
        finally:
            delete object oProfLogger no-error.
        end finally.
    end method. /* WriteProfiler */


    /***** Public Methods *****/


    method public logical GetABLObjectsReport ( input pcSource as character ):
        /**
         * Trigger an all-in-one test case of the ABLObjectsReport by enabling
         * tracking of objects, report gathered data, and stop tracking. For
         * real-world use these actions should be performed at distinct times
         * within the application and only when necessary.
         */

        /* Prime the pump by getting a list of agents for this PAS instance. */
        oABLObjectsReport = new ABLObjectsReport(pcSource).
        oABLObjectsReport:getAgents().

        /* Set up tracking of the ABL Objects, gather a report, and turn off tracking. */
        if oABLObjectsReport:TrackABLObjects(true) then do:
            define variable oReport as JsonObject no-undo.

            assign oReport = oABLObjectsReport:ParseABLObjectReport().
            oReport:WriteFile(substitute("&1/ABLObjectsReport-&2.json",
                                         right-trim(replace(session:temp-directory, "~\", "~/"), "~/"),
                                         replace(iso-date(now), ":", "")), true).

            return true.
        end. /* tracking enabled */
        else
            undo, throw new AppError("Unable to enable ABLObjects tracking.", 0).

        return false.

        catch err as Progress.Lang.Error:
            /* Should fail silently, while delivering errors to the standard local. */
            message err:GetMessage(1).
            return false.
        end catch.
        finally:
            /* Always attempt to disable tracking for this particular test. */
            oABLObjectsReport:TrackABLObjects(false).
            delete object oABLObjectsReport no-error.
        end finally.
    end method. /* GetABLObjectsReport */

end class.
