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

class Business.UnitTest.BadObjects use-widget-pool:

    define temp-table tt1
        field f1 as character
        .

    define public property oArray as JsonArray no-undo
        get():
            if not valid-object(oArray) then do:
                assign oArray = new JsonArray().
                message "Created Array Property:" oArray:ToString().
            end.
            return oArray.
        end get.
        private set.


    destructor public BadObjects ( ):
        define variable oTemp as Progress.Lang.Object no-undo.

        /* Comment-out to leave objects from array present. */
        delete object this-object:oArray no-error.

        message "Destructor".
        oTemp = session:first-object.
        do while valid-object(oTemp):
            if oTemp:GetClass():TypeName begins "Progress.Json." then
                message oTemp:ToString().
            oTemp = oTemp:next-sibling.
        end.
    end destructor.


    method private JsonArray LoadArray ( ):
        define variable oParser  as ObjectModelParser.
        define variable oJsonArr as JsonArray  no-undo.
        define variable oJsonObj as JsonObject no-undo.
        define variable ix       as integer no-undo.

        assign oJsonArr = new JsonArray().
        message "Created Array Variable:" oJsonArr:ToString().
        do ix = 1 to 100:
            assign oJsonObj = new JsonObject().
            oJsonObj:Add("iteration", ix).
            oJsonObj:Add("company", "Progress").
            oJsonArr:Add(oJsonObj).
        end.

        do on error undo, throw:
            assign oParser = new ObjectModelParser().
            oParser:Parse(oJsonArr:GetJsonText()).

            catch parseErr as Progress.Json.JsonParserError:
                undo, throw new AppError(parseErr:GetMessage(1)).
            end catch.
        end.

        message "Original Array:" oJsonArr:Length.

        /* Returning this with the FINALLY block in place will delete the array. */
/*        return oJsonArr.*/

        /**
         * This will allow the FINALLY block to delete the array,
         * which also returns all child objects originally present.
         */
        return cast(oJsonArr:Clone(), JsonArray).

        finally:
            /* Comment-out to leave objects from array present. */
/*            delete object oParser no-error. */
/*            delete object oJsonObj no-error.*/
/*            delete object oJsonArr no-error.*/
        end finally.
    end method. /* LoadArray */


    method private void LoadPropArray ( ):
        define variable oJsonObj as JsonObject no-undo.
        define variable ix       as integer no-undo.

        do ix = 1 to 100:
            assign oJsonObj = new JsonObject().
            oJsonObj:Add("iteration", ix).
            oJsonObj:Add("company", "Progress").
            this-object:oArray:Add(cast(oJsonObj, JsonObject)).
            delete object oJsonObj no-error.
        end.

        message "Original Array:" this-object:oArray:Length.
    end method. /* LoadPropArray */


    @openapi.openedge.export(type="REST", useReturnValue="false", writeDataSetBeforeImage="false").
    @progress.service.resourceMapping(type="REST", operation="invoke", URI="/pollute", alias="pollute", mediaType="application/json").
    method public void PolluteMemory ( output completed as logical ):
        /* Run some faulty code to produce some known objects in session memory. */
        define variable hDS  as handle.
        define variable hDS2 as handle.
        define variable hBuf as handle.

        create dataset hDS.
        create dataset hDS2.

        assign hBuf = buffer tt1:handle.

        message "Load Array:" this-object:LoadArray():Length.
        this-object:LoadPropArray().
        message "Prop Array:" this-object:oArray:Length.

        catch err as Progress.Lang.Error:
            message err:GetMessage(1).
        end catch.
        finally:
            assign completed = true.
        end finally.
    end method. /* PolluteMemory */

end class.
