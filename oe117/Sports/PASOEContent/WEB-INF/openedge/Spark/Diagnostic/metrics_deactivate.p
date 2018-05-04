/*------------------------------------------------------------------------
    File        : metrics_deactivate.p
    Purpose     : Runs logic on deactivate event of a request
    Description :
    Author(s)   : Dustin Grau
    Created     : Thu May 03 11:14:13 EDT 2018
    Notes       : PAS: Assign as sessionDeactivateProc in openedge.properties
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

using Progress.Lang.* from propath.

block-level on error undo, throw.

/* ***************************  Main Block  *************************** */

/* Stop the profiler for this request. */
Spark.Diagnostic.Util.OEMetrics:Instance:WriteProfiler().

/* Generate an ABLObjects report. */
Spark.Diagnostic.Util.OEMetrics:Instance:GetABLObjectsReport().
