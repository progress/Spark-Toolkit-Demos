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
        oABLObjectsReport:getAgents().
    end constructor.

    method public logical GetABLObjectsReport ( input pcMonitoringMethod as character ):
        /* @TODO: Need to address running this via OEManager or JMX. */
        oABLObjectsReport:TrackABLObjects(true).
        oABLObjectsReport:ParseABLObjectReport().
        oABLObjectsReport:TrackABLObjects(false).

        return true.

        catch err as Progress.Lang.Error:
            return false.
        end catch.
    end method. /* GetABLObjectsReport */

end class.
