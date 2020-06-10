/*------------------------------------------------------------------------
    File        : RunCode
    Purpose     : Test harness for runtime code examples
    Author(s)   : Dustin Grau (dugrau@progress.com)
    Created     : Mon Aug 6 10:48:07 EDT 2019
    Notes       :
  ----------------------------------------------------------------------*/

@program FILE(name="RunCode.cls", module="AppServer").
@openapi.openedge.export FILE(type="REST", executionMode="singleton", useReturnValue="false", writeDataSetBeforeImage="false").
@progress.service.resource FILE(name="runcode", URI="/runcode", schemaName="", schemaFile="").

using Progress.Lang.* from propath.
using Progress.Json.ObjectModel.* from propath.

block-level on error undo, throw.

class Business.UnitTest.RunCode inherits Spark.Core.Service.Service use-widget-pool:

    method public override void initialize ( ):
    end method. /* initialize */

    method public override void dispose ( ):
    end method. /* dispose */

    @openapi.openedge.export(type="REST", useReturnValue="false", writeDataSetBeforeImage="false").
    @progress.service.resourceMapping(type="REST", operation="invoke", URI="/busy", alias="busy", mediaType="application/json").
    method public void lookBusy ( input  busyTime as integer,
                                  output elapsed  as integer ):
        /* If no time specified then default to 1000 milliseconds. */
        if busyTime eq ? then assign busyTime = 1000.

        if busyTime lt 0 then /* Throw an error if the provided value is negative; SEE allows changing of the response code. */
            undo, throw new OpenEdge.Web.SendExceptionError(OpenEdge.Net.HTTP.StatusCodeEnum:BadRequest,
                                                            "Busy Time parameter cannot be less than zero.").

        /* Run a wait loop for some period to imitate long-running code. */
        define variable iStart as datetime no-undo.
        assign iStart = now.
        pause (busyTime / 1000) no-message.

        finally:
            /* Confirm that execution paused for the time stated. */
            assign elapsed = interval(now, iStart, "milliseconds").
        end finally.
    end method. /* lookBusy */

    @openapi.openedge.export(type="REST", useReturnValue="false", writeDataSetBeforeImage="false").
    @progress.service.resourceMapping(type="REST", operation="invoke", URI="/busydo", alias="busydo", mediaType="application/json").
    method public void doBusy ( input  busyTime as integer,
                                output elapsed  as integer ):
        /* If no time specified then default to 1000 milliseconds. */
        if busyTime eq ? then assign busyTime = 1000.

        if busyTime lt 0 then /* Throw an error if the provided value is negative; SEE allows changing of the response code. */
            undo, throw new OpenEdge.Web.SendExceptionError(OpenEdge.Net.HTTP.StatusCodeEnum:BadRequest,
                                                            "Busy Time parameter cannot be less than zero.").

        /* Run a do loop for some period to imitate long-running code. */
        define variable dStart as datetime  no-undo.
        define variable dNow   as datetime  no-undo.
        define variable oArr   as JsonArray no-undo.
        define variable iCount as int64     no-undo.

        assign dStart = now.
        assign oArr = new JsonArray().
        
        repeat:
            assign iCount = iCount + 1.
            assign dNow = now.
            if oArr:length eq 0 then
                oArr:Add(dNow).
            else if dNow ne oArr:GetDatetime(oArr:length) then
                oArr:Add(dNow).
            if interval(now, dStart, "milliseconds") ge busyTime then leave.
        end.

        finally:
            /* Confirm that execution paused for the time stated. */
            assign elapsed = interval(now, dStart, "milliseconds").
            if log-manager:logging-level ge 4 then
                oArr:WriteFile(session:temp-directory + "/busy.json", true).
            delete object oArr no-error.
        end finally.
    end method. /* doBusy */

    @openapi.openedge.export(type="REST", useReturnValue="false", writeDataSetBeforeImage="false").
    @progress.service.resourceMapping(type="REST", operation="invoke", URI="/stop", alias="stop", mediaType="application/json").
    @openapi.openedge.method.property(name="verb", value="get").
    method public void stopCode ( output completed as logical ):
        stop. /* Trigger a stop condition for this code. */

        finally:
            assign completed = true. /* This really should't return with a STOP. */
        end finally.
    end method. /* lookBusy */

end class.