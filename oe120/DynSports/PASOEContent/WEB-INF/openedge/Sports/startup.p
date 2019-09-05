/*------------------------------------------------------------------------
    File        : startup.p
    Purpose     :
    Description : Assigned as sessionStartupProc in openedge.properties
    Author(s)   : Dustin Grau (dugrau@progress.com)
    Created     : Wed Jan 30 10:03:17 EDT 2019
    Notes       :
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

block-level on error undo, throw.

/* Standard input parameter as set via sessionStartupProcParam */
define input parameter startup-data as character no-undo.

procedure logMessage private:
    define input parameter pcMessage   as character no-undo.
    define input parameter pcSubSystem as character no-undo.

    if valid-handle(log-manager) and log-manager:logfile-name ne ? then
        log-manager:write-message (pcMessage, caps(pcSubSystem)).
    else
        message substitute("&1~n&2", pcSubSystem, pcMessage).
end procedure. /* logMessage */

/* Optional: Startup the metrics from the diagnostic tools. */
run Spark/Diagnostic/metrics_startup ( input startup-data ).

/**
 * Run the default startup procedure.
 * -Starts CCS application.
 * -Prepares any logging features.
 * -Starts all lifecycles, managers.
 */
run Spark/startup ( input startup-data ).

catch err as Progress.Lang.Error:
    run logMessage (substitute("Error: &1", err:GetMessage(1)), "STARTUP").
end catch.

