/*------------------------------------------------------------------------
    File        : Sports/activate.p
    Purpose     : Add logic to profile the application, by-request.
    Description : Includes latent code that can be easily turned on/off.
    Author(s)   : Dustin Grau (dugrau@progress.com)
    Created     : Wed Feb 7 11:16:43 EDT 2018
    Notes       :
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

block-level on error undo, throw.

define variable lUseProfiler as logical   no-undo initial false.
define variable cRoot        as character no-undo.
define variable cPath        as character no-undo.
define variable hCPO         as handle    no-undo.

/* ***************************  Main Block  *************************** */

do on error undo, leave:
    /* Locate the root directory of the PAS instance. */
    file-info:filename = os-getenv("CATALINA_BASE").
    assign cRoot = right-trim(replace(file-info:full-pathname, "~\", "~/"), "~/").
    if cRoot ne ? and index(file-info:file-type, "D") ne 0 then
        assign cRoot = cRoot + "~/".

    /* Locate an indicator file that the profiler should be used. */
    file-info:filename = substitute("&1/conf/profiler.on", cRoot).
    if file-info:full-pathname ne ? then
        assign lUseProfiler = true.
end. /* do */

/* Obtain the CP object handle from the session request info. */
assign hCPO = session:current-request-info:GetClientPrincipal() no-error.

if valid-handle(hCPO) and lUseProfiler then
do on error undo, leave:
    /* Determine proper temp directory for the application. */
    assign cPath = replace(session:temp-directory, "~\", "~/").

    /* Determine output location for listing files. */
    define variable cListDir as character no-undo.
    assign cListDir = substitute("&1/listing/", right-trim(cPath, "~/")).
    os-create-dir value(cListDir).

    assign /* Note: Order matters here, do not rearrange! */
        profiler:enabled      = true
        profiler:profiling    = true
        profiler:file-name    = substitute("&1/profilerOut_&2_&3.prof", right-trim(cPath, "~/"), mtime, hCPO:session-id)
        profiler:description  = substitute("Profiler Output - &1", hCPO:session-id)
        profiler:listings     = true /* Note: Requires source code. */
        profiler:directory    = cListDir
        profiler:trace-filter = "*":u
        profiler:tracing      = "":u
        profiler:coverage     = true
        profiler:statistics   = true
        .
end. /* valid-handle */

catch err as Progress.Lang.Error:
    message substitute("Error: &1 (&2)", err:GetMessage(1), err:GetMessageNum(1)).
end catch.
finally:
    delete object hCPO no-error.
end finally.
