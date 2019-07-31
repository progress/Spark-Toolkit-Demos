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

block-level on error undo, throw.

/* ***************************  Main Block  *************************** */

/* Obtain the current request information. */
define variable oRequest as OERequestInfo no-undo.
assign oRequest = cast(session:current-request-info, OERequestInfo).

/* Optional: Report what is being run currently via APSV transport. */
if oRequest:AdapterType:ToString() eq "APSV" then
do on error undo, leave:
    define variable oLogger  as ILogWriter no-undo.
    define variable cMethod  as character  no-undo.
    define variable cProgram as character  no-undo.
    define variable hCPO     as handle     no-undo.

    /* This assumes use of a logging object "AppServerTransport" to be defined in the logging.config file, located in the PROPATH. */
    assign
        oLogger  = LoggerBuilder:GetLogger("AppServerTransport") /* Name of the special logging object to be found in logging.config */
        cProgram = entry(1, oRequest:ProcedureName, "&") /* Should be the original procedure name. */
        cMethod  = entry(2, oRequest:ProcedureName, "&") when num-entries(oRequest:ProcedureName, "&") ge 2 /* Internal procedure, if present. */
        hCPO     = oRequest:GetClientPrincipal() /* Obtain the CP token passed. */
        .

    /* Output any values you wish, to be timestamped within the associated log file. */
    oLogger:Info(substitute("&1 | &2 &3",
                            if valid-handle(hCPO) then hCPO:session-id else "UNKNOWN_SESSION", trim(cProgram), trim(cMethod))).

    finally:
        delete object hCPO no-error.
        delete object oLogger no-error.
    end finally.
end. /* APSV */

/* Optional: Activate the metrics from the diagnostic tools. */
run Spark/Diagnostic/metrics_activate.

catch err as Progress.Lang.Error:
    /* Catch and Release */
    message substitute("Activate Error: &1", err:GetMessage(1)).
end catch.
finally:
    delete object oRequest no-error.
end finally.
