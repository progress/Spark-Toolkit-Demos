/*------------------------------------------------------------------------
    File        : OEMetrics
    Purpose     : OE metrics for current PAS instance 
    Description : 
    Author(s)   : Dustin Grau (dugrau@progress.com)
    Created     : Wed Apr 25 13:58:59 EDT 2018
    Notes       : 
  ----------------------------------------------------------------------*/

using Progress.Lang.* from propath.
using Progress.Json.ObjectModel.* from propath.
using Spark.Core.Util.ABLObjectsReport from propath.

block-level on error undo, throw.

class Spark.Core.Util.OEMetrics use-widget-pool: 

    define variable oABLObjectsReport as ABLObjectsReport no-undo.

    constructor OEMetrics ( ):
        /* Prime the pump by getting a list of agents for this PAS instance. */
        oABLObjectsReport = new ABLObjectsReport().
        oABLObjectsReport:GetAgents().
    end constructor.

    method public void getABLObjectsReport ( ):
        oABLObjectsReport:trackABLObjects(true).
/*        oABLObjectsReport:trackABLObjects(false).*/
    end method. /* getABLObjectsReport */

end class.