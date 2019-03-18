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

    define public override property serviceURI as character
        initial "/web/api/tests" no-undo get.
        protected set.

    define public override property resourceName as character
        initial "leakycode" no-undo get.
        protected set.

    method public override void initialize ( ):
        /* Describe any properties about invoke methods to be exposed. */
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "badHandle", "handle", "get").
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "badMemptr", "memptr", "get").
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "badObject", "object", "get").
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "badQuery", "query", "get").
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "badString", "string", "get").
    end method. /* initialize */

    method public void badHandle ( output textMessage as character ):
        define variable hProc as handle no-undo.

        run Business/HelloProc persistent set hProc.
        run sayHello in hProc ( "World", output textMessage).
        
        /* DO NOT clean up the persistent handle, but instead let it linger. */
    end method. /* badHandle */

    method public void badMemptr ( output pointerSize as integer ):
        define variable mPtr as memptr no-undo.

        set-size(mPtr) = 100. /* Set it, but DO NOT reset size to 0 after use.*/
        assign pointerSize = get-size(mPtr).
    end method. /* badMemptr */

    method public void badObject ( output textMessage as character ):
        define variable oJSON as JsonObject no-undo.

        assign oJSON = new JsonObject().
        oJson:Add("test1", "Hello USA!"). /* Created and populated with data. */

        assign oJSON = new JsonObject(). /* Creates a new object instance in the same variable. */
        oJson:Add("test2", "Hello World!"). /* Should be the value output to the user in the API. */

        assign textMessage = string(oJson:GetJsonText()).

        /* DO NOT clean up the JSON object(s) created. */
    end method. /* badObject */

    method public void badQuery ( output totalRecords as integer ):
        define variable hQuery as handle no-undo.

        create query hQuery.
        hQuery:set-buffers(buffer Customer:handle).
        hQuery:query-prepare("preselect each customer").
        hQuery:query-open.
        assign totalRecords = hQuery:num-results.

        /* DO NOT close the query nor delete the handle. */
    end method. /* badQuery */

    method public void badString ( output textMessage as character ):
        define variable lcString as longchar no-undo.

        assign lcString = "Hello World!".
        assign textMessage = string(lcString).

        /* DO NOT reset the longchar variable to an unknown value. */
    end method. /* badString */

end class.