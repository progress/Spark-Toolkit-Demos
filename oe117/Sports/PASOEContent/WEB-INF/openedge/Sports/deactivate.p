/*------------------------------------------------------------------------
    File        : deactivate.p
    Purpose     : Runs logic on deactivate event of a request
    Description :
    Author(s)   : Dustin Grau
    Created     : Thu May 03 11:14:13 EDT 2018
    Notes       : PAS: Assign as sessionDeactivateProc in openedge.properties
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

block-level on error undo, throw.

/* ***************************  Main Block  *************************** */

/* Stop the metrics from the diagnostic tools. */
run Spark/Diagnostic/metrics_deactivate.
