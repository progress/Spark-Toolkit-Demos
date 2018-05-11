/*------------------------------------------------------------------------
    File        : BadObjects
    Syntax      :
    Author(s)   : Dustin Grau
    Created     : Fri May 11 11:58:13 EDT 2018
    Notes       :
  ----------------------------------------------------------------------*/

@program FILE(name="BadObjects.cls", module="AppServer").
@openapi.openedge.export FILE(type="REST", executionMode="singleton", useReturnValue="false", writeDataSetBeforeImage="false").
@progress.service.resource FILE(name="objects", URI="/objects", schemaName="", schemaFile="").

using Progress.Lang.* from propath.
using Progress.Json.ObjectModel.* from propath.

block-level on error undo, throw.

class Business.UnitTest.BadObjects inherits Spark.Core.Service.SparkEntity use-widget-pool:

    define temp-table tt1
        field f1 as character
        .

    @openapi.openedge.export(type="REST", useReturnValue="false", writeDataSetBeforeImage="false").
    @progress.service.resourceMapping(type="REST", operation="invoke", URI="/pollute", alias="pollute", mediaType="application/json").
    method public void PolluteMemory ( output completed as logical ):
        /* Run some faulty code to produce some known objects in session memory. */
        define variable hDS      as handle.
        define variable hDS2     as handle.
        define variable hBuf     as handle no-undo.
        define variable oParser  as ObjectModelParser.
        define variable oJsonObj as JsonObject.

        create dataset hDS.
        create dataset hDS2.

        assign hBuf = buffer tt1:handle.

        assign oJsonObj = new JsonObject().
        oJsonObj:Add("company", "Progress").
        
        do on error undo, throw:
            assign oParser = new ObjectModelParser().
            oParser:Parse(oJsonObj:GetJsonText()).

            catch parseErr as Progress.Json.JsonParserError:
                undo, throw new AppError(parseErr:GetMessage(1)).
            end catch.
        end.

        catch err as Progress.Lang.Error:
            message err:GetMessage(1).
        end catch.
        finally:
            assign completed = true.
        end finally.
    end method. /* PolluteMemory */

end class.
