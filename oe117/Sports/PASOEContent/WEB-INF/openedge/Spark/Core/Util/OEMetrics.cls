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

    define public static property RequestStart as datetime-tz no-undo
        get. private set.

    define private variable oABLObjectsReport as ABLObjectsReport no-undo.


    /***** Static Methods *****/


    method public static logical StartProfiler ( input pcFilter as character ):
        define variable oRequestInfo as OERequestInfo no-undo.
        define variable lFilterMatch as logical       no-undo initial false.
        define variable cOutPath     as character     no-undo.
        define variable ix           as integer       no-undo.

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
            assign cOutPath = substitute("&1/Profiler_&2_&3_&4.prof",
                                         right-trim(session:temp-directory, "~/"), RequestCount,
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
        define variable oRequestInfo as OERequestInfo no-undo.
        define variable oProfLogger  as ILogWriter    no-undo.
        define variable iExecTime    as integer       no-undo.

        assign oProfLogger = LoggerBuilder:GetLogger("Spark.Core.Util.OEMetrics").
        assign oRequestInfo = cast(session:current-request-info, OERequestInfo).
        assign iExecTime = interval(now, RequestStart, "milliseconds" ).

        oProfLogger:Info(substitute("&1: &2ms", oRequestInfo:ProcedureName, iExecTime)).

        if profiler:enabled then do:
            /* Turn off the profiler, if enabled. */
            assign
                profiler:profiling = false
                profiler:enabled   = false
                .

            /* Only write the data out if execution time exceeds threshold. */
            if piMinExecTime eq ? or piMinExecTime lt 0 then assign piMinExecTime = 0.
            if iExecTime gt piMinExecTime then
                profiler:write-data().

            return true.
        end. /* profiler:enabled */

        return false. /* Profiler not enabled. */

        catch err as Progress.Lang.Error:
            /* Should fail silently, while delivering errors to the standard local. */
            message err:GetMessage(1).
            return false.
        end catch.
    end method. /* WriteProfiler */


    /***** Public Methods *****/


    method public logical GetABLObjectsReport ( input pcSource as character ):
        /* Prime the pump by getting a list of agents for this PAS instance. */
        oABLObjectsReport = new ABLObjectsReport(pcSource).
        oABLObjectsReport:getAgents().

        /* Set up tracking of the ABL Objects, gather a report, and turn off tracking. */
        oABLObjectsReport:TrackABLObjects(true).
        oABLObjectsReport:ParseABLObjectReport().
        oABLObjectsReport:TrackABLObjects(false).

        return true.

        catch err as Progress.Lang.Error:
            /* Should fail silently, while delivering errors to the standard local. */
            message err:GetMessage(1).
            return false.
        end catch.
    end method. /* GetABLObjectsReport */

end class.
