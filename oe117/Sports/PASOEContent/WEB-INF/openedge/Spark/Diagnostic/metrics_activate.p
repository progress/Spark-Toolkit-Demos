/*------------------------------------------------------------------------
    File        : metrics_activate.p
    Purpose     : Runs logic on activate event of a request
    Description :
    Author(s)   : Dustin Grau
    Created     : Thu May 03 11:14:04 EDT 2018
    Notes       : PAS: Assign as sessionActivateProc in openedge.properties
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

block-level on error undo, throw.

/* ***************************  Main Block  *************************** */

/* Begin tracking ABLObjects for the current agent. */
/* WARNING: This can cause a delay in the request, use with caution. */
/*Spark.Diagnostic.Util.OEMetrics:Instance:StartTrackingObjects().*/

/* Start the profiler for this request. */
Spark.Diagnostic.Util.OEMetrics:Instance:StartProfiler().
