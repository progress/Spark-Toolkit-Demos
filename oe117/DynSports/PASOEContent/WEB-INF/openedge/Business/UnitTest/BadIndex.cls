/*------------------------------------------------------------------------
    File        : BadIndex
    Purpose     : Test harness for bad index (signature mismatch) issue
    Author(s)   : Dustin Grau (dugrau@progress.com)
    Created     : Thu Mar 23 08:56:07 EDT 2017
    Notes       :
  ----------------------------------------------------------------------*/

using Progress.Lang.* from propath.
using Spark.Core.Manager.ISchemaManager from propath.

block-level on error undo, throw.

class Business.UnitTest.BadIndex inherits Spark.Core.Service.DynamicResource:

    define public override property serviceURI as character
        initial "/web/api/tests" no-undo get.
        protected set.

    define public override property resourceName as character
        initial "badindex" no-undo get.
        protected set.

    define protected property oSchemaManager as ISchemaManager no-undo
        get:
            if not valid-object(oSchemaManager) then
                assign oSchemaManager = cast(Ccs.Common.Application:StartupManager:getManager(get-class(ISchemaManager)), ISchemaManager).
            return oSchemaManager.
        end get.
        set.

    /**
     * Indices should be listed with primary first, then unique, then all others.
     * This is due to an issue in the XML-SCHEMA data that re-orders the indices
     * in a particular order, resulting in a temp-table mis-match when the dynamic
     * invoke of a method must pass that structure as a parameter. To trigger this
     * issue on older OE versions, simply add plain indexes just before the primary.
     */
    define temp-table ttTest no-undo
        field EmployeeID as integer
        field Number     as integer
        field Username   as character
        field Firstname  as character
        field Lastname   as character
        index Username   is unique Username ascending
        index Lastname   is unique Lastname ascending
        index EmployeeID is primary unique EmployeeID ascending
        index Number     Number ascending
        .
    define dataset dsTest for ttTest.

    method public override void initialize ( ):
        define variable hDataset as handle no-undo.

        /* Describe schema for any datasets to be exposed. */
        assign hDataset = dataset dsTest:handle.
        oSchemaManager:registerDataset(input hDataset).

        /* Describe any properties about invoke methods to be exposed. */
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "testOutput", "output", "get").
    end method. /* initialize */

    method public void testOutput ( output dataset for dsTest ):
        create ttTest.
        assign
            ttTest.EmployeeID = 1
            ttTest.Number     = 1
            ttTest.Username   = "Test"
            .
    end method. /* testOutput */

end class.