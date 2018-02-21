/*------------------------------------------------------------------------
    File        : Sports/deactivate.p
    Purpose     : Turn off the profiler and output results.
    Description : 
    Author(s)   : Dustin Grau (dugrau@progress.com)
    Created     : Wed Feb 7 11:16:43 EDT 2018
    Notes       :
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

block-level on error undo, throw.

/* ***************************  Main Block  *************************** */

if profiler:enabled then
do on error undo, leave:
    /* Turn off the profiler, if enabled. */
    assign
        profiler:profiling = false
        profiler:enabled   = false
        .

    /* Make sure you actually WRITE the data out. */
    profiler:write-data().
end. /* profiler:enabled */
