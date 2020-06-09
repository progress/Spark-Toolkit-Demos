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

/* Proposed annotations for service assignment and API versioning. */
@openapi.openedge.service(name="tests").
@openapi.openedge.resource.version(major="1", minor="0", patch="1").

/* Proposed annotation to set security options for this resource overall. */
@openapi.openedge.resource.security(denyAll="true").

using Progress.Lang.*.
using Spark.Core.Util.ApplicationError from propath.

block-level on error undo, throw.

class Business.UnitTest.AnnoTest use-widget-pool: 

    @openapi.openedge.export(type="REST", useReturnValue="false", writeDataSetBeforeImage="false").
    @progress.service.resourceMapping(type="REST", operation="invoke", URI="/test", alias="msgTest", mediaType="application/json").
    @openapi.openedge.method.property(name="verb", value="post").

    /* Proposed annotations for adjusting exposure of parameters (message elements). */
    @openapi.openedge.method.parameter(name="messageType", type="field", alias="type").
    @openapi.openedge.method.parameter(name="messageText", type="field", alias="text").

    /* Proposed annotation to set distinct security options on this method only. */
    @openapi.openedge.method.security(role="ROLE_PSCUser|ROLE_ANONYMOUS").
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