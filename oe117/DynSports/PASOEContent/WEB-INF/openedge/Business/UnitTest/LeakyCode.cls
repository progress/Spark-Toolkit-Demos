/*------------------------------------------------------------------------
    File        : LeakyCode
    Purpose     : Test harness for leaky code examples
    Author(s)   : Dustin Grau (dugrau@progress.com)
    Created     : Mon Mar 18 010:48:07 EDT 2019
    Notes       :
  ----------------------------------------------------------------------*/

using Progress.Lang.* from propath.
using Progress.Json.ObjectModel.* from propath.

block-level on error undo, throw.

class Business.UnitTest.LeakyCode inherits Spark.Core.Service.DynamicResource:

    /* Will be used to demonstrate a hanging buffer. */
    define temp-table tt1
        field f1 as character
        .

    /* Will be used to illustrate a lingering object. */
    define public property oArray as JsonArray no-undo
        get():
            if not valid-object(oArray) then
                assign oArray = new JsonArray().

            return oArray.
        end get.
        private set.

    method private void LoadArray ( ):
        define variable oJsonObj as JsonObject no-undo.
        define variable ix       as integer no-undo.

        do ix = 1 to 100:
            assign oJsonObj = new JsonObject().
            oJsonObj:Add("iteration", ix).
            oJsonObj:Add("company", substitute("Progress: &1", ix)).
            this-object:oArray:Add(oJsonObj).
        end.
    end method. /* LoadPropArray */

    define public override property serviceURI as character
        initial "/web/api/tests" no-undo get.
        protected set.

    define public override property resourceName as character
        initial "leakycode" no-undo get.
        protected set.

    method public override void initialize ( ):
        /* Describe any properties about invoke methods to be exposed. */
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "badBuffer", "buffer", "get").
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "badHandle", "handle", "get").
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "badMemptr", "memptr", "get").
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "badObject", "object", "get").
    end method. /* initialize */

    method public void badBuffer ( output completed as logical ):
        /* Create some buffers that will not be cleaned up. */
        define variable hDS  as handle.
        define variable hDS2 as handle.
        define variable hBuf as handle.

        create dataset hDS.
        create dataset hDS2.

        assign hBuf = buffer tt1:handle.

        finally:
            /* DO NOT clean up the datasets nor buffer handle. */
            assign completed = true.
        end finally.
    end method. /* badBuffer */

    method public void badHandle ( output textMessage as character ):
        define variable hProc as handle no-undo.

        run Business/HelloProc persistent set hProc.
        run sayHello in hProc ( "World", output textMessage).

        /* DO NOT clean up the persistent handle, but instead let it linger. */
    end method. /* badHandle */

    method public void badMemptr ( output pointerSize as integer ):
        define variable mPtr as memptr no-undo.

        set-size(mPtr) = 100. /* Set a size, but DO NOT reset to 0 after use.*/
        assign pointerSize = get-size(mPtr).
    end method. /* badMemptr */

    method public void badObject ( output arrayLength as integer ):
        this-object:LoadArray(). /* Add data to the class-scoped array. */
        assign arrayLength = this-object:oArray:Length.

        /* DO NOT clean up the JSON array created. */
    end method. /* badObject */

end class.