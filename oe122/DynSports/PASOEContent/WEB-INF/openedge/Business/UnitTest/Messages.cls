/*------------------------------------------------------------------------
    File        : Messages
    Purpose     :
    Syntax      :
    Description :
    Author(s)   : Dustin Grau (dgrau@progress.com)
    Created     : Fri Jan 06 09:45:59 EST 2017
    Notes       :
  ----------------------------------------------------------------------*/

using Progress.Lang.* from propath.
using Spark.Core.Util.ApplicationError from propath.

block-level on error undo, throw.

class Business.UnitTest.Messages inherits Spark.Core.Service.DynamicResource:

    define public override property serviceURI as character
        initial "/web/api/tests" no-undo get.
        protected set.

    define public override property resourceName as character
        initial "message" no-undo get.
        protected set.

    method public override void initialize ( ):
        /* Describe any properties about invoke methods to be exposed. */
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "testMessage", "test", "put").
    end method. /* initialize */

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