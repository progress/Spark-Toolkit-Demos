/*------------------------------------------------------------------------
    File        : activate.p
    Purpose     : Runs logic on activate event of a request
    Description :
    Author(s)   : Dustin Grau
    Created     : Thu May 03 11:14:04 EDT 2018
    Notes       : PAS: Assign as sessionActivateProc in openedge.properties
  ----------------------------------------------------------------------*/

using Progress.Lang.* from propath.
using OpenEdge.Logging.* from propath.

/* ***************************  Definitions  ************************** */

block-level on error undo, throw.

/* ***************************  Main Block  *************************** */

/* Obtain the current request information. */
define variable oRequest as OERequestInfo no-undo.
assign oRequest = cast(session:current-request-info, OERequestInfo).

/* Report what is being run currently via APSV transport. */
if oRequest:AdapterType:ToString() eq "APSV" then do:
    define variable oLogger  as ILogWriter no-undo.
    define variable cMethod  as character  no-undo.
    define variable cProgram as character  no-undo.

    assign
        oLogger  = LoggerBuilder:GetLogger("AppServerTransport")
        cProgram = entry(1, oRequest:ProcedureName, "&")
        cMethod  = entry(2, oRequest:ProcedureName, "&") when num-entries(oRequest:ProcedureName, "&") ge 2
        .
    oLogger:Info(substitute("&1 | &2 &3", oRequest:ClientContextId, cProgram, cMethod)).
    delete object oLogger no-error.
end. /* APSV */

/* Startup the metrics from the diagnostic tools. */
run Spark/Diagnostic/metrics_activate.

catch err as Progress.Lang.Error:
    /* Catch and Release */
    message substitute("Metrics Activate Error: &1", err:GetMessage(1)).
end catch.
finally:
    delete object oRequest no-error.
end finally.
