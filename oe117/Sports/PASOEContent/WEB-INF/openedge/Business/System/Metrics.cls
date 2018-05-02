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
using Spark.Core.Util.OEMetrics from propath.

block-level on error undo, throw.

class Business.System.Metrics: 

    /* @TODO: Implement a config file and options to drive operation of these features. */

    @openapi.openedge.export(type="REST", useReturnValue="false", writeDataSetBeforeImage="false").
    @progress.service.resourceMapping(type="REST", operation="invoke", URI="/objects", alias="objects", mediaType="application/json").
    method public void GetObjects ( output success as logical ):
        /* Begin the code profiler, filtered by specific programs. */
        OEMetrics:StartProfiler("*").

        /* When creating the object, must specify source as OEManager or JMX. */
        assign success = OEMetrics:Instance:GetABLObjectsReport("oejmx").

        /* End profiling and flush data if execution time exceeds given time (in ms). */
        OEMetrics:WriteProfiler(1000). /* Example: Output requests taking 1s or more. */
    end method. /* GetObjects */

end class.
