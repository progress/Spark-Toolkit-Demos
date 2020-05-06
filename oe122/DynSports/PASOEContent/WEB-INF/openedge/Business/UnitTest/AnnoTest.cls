/*------------------------------------------------------------------------
    File        : AnnoTest
    Purpose     : 
    Syntax      : 
    Description : 
    Author(s)   : Dustin Grau
    Created     : Wed May 06 13:12:28 EDT 2020
    Notes       : 
  ----------------------------------------------------------------------*/

@program FILE(name="AnnoTest.cls", module="AppServer").
@openapi.openedge.export FILE(type="REST", executionMode="singleton", useReturnValue="false", writeDataSetBeforeImage="false").
@progress.service.resource FILE(name="annotatedTest", URI="/annotated", schemaName="", schemaFile="").

using Progress.Lang.*.
using Spark.Core.Util.ApplicationError from propath.

block-level on error undo, throw.

class Business.UnitTest.AnnoTest use-widget-pool: 

    @openapi.openedge.export(type="REST", useReturnValue="false", writeDataSetBeforeImage="false").
    @progress.service.resourceMapping(type="REST", operation="invoke", URI="/test", alias="test", mediaType="application/json").
    @openapi.openedge.method.property (name="verb", value="post").
    method public void testMessage ( input  messageType as character,
                                     output messageText as character ):
        assign messageText = "no type".

        if (messageType gt "") eq true then do on error undo, throw:
            assign messageText = messageType.

            case messageType:
                when "Teapot" then
                    undo, throw new AppError("I'm a teapot", -418).
                when "AppError" then
                    undo, throw new AppError("This is an AppError", -500).
                when "ApplicationError" then
                    undo, throw new ApplicationError("This is an ApplicationError", -500).
                when "Stop" then
                    stop.
            end case.
        end.
    end method.

end class.