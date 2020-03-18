/*------------------------------------------------------------------------
    File        : Messages
    Purpose     :
    Syntax      :
    Description :
    Author(s)   : Dustin Grau (dgrau@progress.com)
    Created     : Fri Jan 06 09:45:59 EST 2017
    Notes       :
  ----------------------------------------------------------------------*/

@program FILE(name="Messages.cls", module="AppServer").
@openapi.openedge.export FILE(type="REST", executionMode="singleton", useReturnValue="false", writeDataSetBeforeImage="false").
@progress.service.resource FILE(name="message", URI="/message", schemaName="", schemaFile="").

using Progress.Lang.* from propath.
using Spark.Core.Util.ApplicationError from propath.

block-level on error undo, throw.

class Business.UnitTest.Messages inherits Spark.Core.Service.SparkEntity use-widget-pool:

    @openapi.openedge.export(type="REST", useReturnValue="false", writeDataSetBeforeImage="false").
    @progress.service.resourceMapping(type="REST", operation="invoke", URI="/test", alias="test", mediaType="application/json").
    method public void testMessage ( input  messageType as character,
                                     output messageText as character ):
        assign messageText = "no type".

        if (messageType gt "") eq true then do on error undo, throw:
            assign messageText = messageType.

            case messageType:
                when "Teapot" then
                    undo, throw new AppError("I'm a teapot", -418).
                when "Info" then
                    this-object:oContextMessage:addMessage(Spark.Core.Util.ErrorTypeEnum:Information, "This is an info message.").
                when "Warn" then
                    this-object:oContextMessage:addMessage(Spark.Core.Util.ErrorTypeEnum:Warning, "This is a warning message.").
                when "Error" then
                    this-object:oContextMessage:addMessage(Spark.Core.Util.ErrorTypeEnum:Error, "This is an error message.").
                when "AppError" then
                    undo, throw new AppError("This is an AppError", -500).
                when "ApplicationError" then
                    undo, throw new ApplicationError("This is an ApplicationError", -500).
                when "Stop" then
                    stop.
                when "Internal" then
                    this-object:oLoggingManager:logMessage("This is an internal message", "INTERNAL", 1).
            end case.
        end.
    end method.

end class.