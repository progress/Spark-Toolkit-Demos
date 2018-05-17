/*------------------------------------------------------------------------
    File        : Metrics
    Purpose     : 
    Description : 
    Author(s)   : Dustin Grau (dugrau@progress.com)
    Created     : Wed Apr 25 14:37:55 EDT 2018
    Notes       : 
  ----------------------------------------------------------------------*/

@program FILE(name="Metrics.cls", module="AppServer").
@openapi.openedge.export FILE(type="REST", executionMode="singleton", useReturnValue="false", writeDataSetBeforeImage="false").
@progress.service.resource FILE(name="metrics", URI="/metrics", schemaName="", schemaFile="").

using Progress.Lang.* from propath.
using Spark.Diagnostic.Util.OEMetrics from propath.

block-level on error undo, throw.

class Business.System.Metrics:

    @openapi.openedge.export(type="REST", useReturnValue="false", writeDataSetBeforeImage="false").
    @progress.service.resourceMapping(type="REST", operation="invoke", URI="/getObjects", alias="getObjects", mediaType="application/json").
    method public void GetObjects ( output success as logical ):
        /* Obtain the current list of Objects in memory for all agents. */
        assign success = OEMetrics:Instance:GetAllABLObjectsReport().
    end method. /* GetObjects */

    @openapi.openedge.export(type="REST", useReturnValue="false", writeDataSetBeforeImage="false").
    @progress.service.resourceMapping(type="REST", operation="invoke", URI="/getSessionObjects", alias="getSessionObjects", mediaType="application/json").
    method public void GetSessionObjects ( output success as logical ):
        /* Obtain the current list of Objects in memory for this agent/session. */
        assign success = OEMetrics:Instance:GetSessionABLObjects().
    end method. /* GetSessionObjects */

    @openapi.openedge.export(type="REST", useReturnValue="false", writeDataSetBeforeImage="false").
    @progress.service.resourceMapping(type="REST", operation="invoke", URI="/startTracking", alias="startTracking", mediaType="application/json").
    method public void StartTracking ( output success as logical ):
        /* Start tracking the ABLObjects for all agents. */
        assign success = OEMetrics:Instance:TrackAllAgents(true).
    end method. /* StartTracking */

    @openapi.openedge.export(type="REST", useReturnValue="false", writeDataSetBeforeImage="false").
    @progress.service.resourceMapping(type="REST", operation="invoke", URI="/stopTracking", alias="stopTracking", mediaType="application/json").
    method public void StopTracking ( output success as logical ):
        /* Stop tracking the ABLObjects for all agents. */
        assign success = OEMetrics:Instance:TrackAllAgents(false).
    end method. /* StopTracking */

end class.
