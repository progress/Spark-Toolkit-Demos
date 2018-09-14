/*------------------------------------------------------------------------
    File        : WebDataBE.cls
    Author(s)   : Code Wizard
    Created     : 08/06/18
    Notes       : Customized BE instance with AFP features available.
  ----------------------------------------------------------------------*/

using Progress.Lang.* from propath.
using Spark.Core.Util.FieldInfo from propath.

block-level on error undo, throw.

class Business.System.WebData inherits Spark.Core.Service.DynamicEntity use-widget-pool:

    {Common/webdatastore.i}

    define public override property serviceURI as character
        initial "/web/api/common" no-undo get.
        protected set.

    define public override property resourceName as character
        initial "webdata" no-undo get.
        protected set.

    define public override property primaryKeys as character
        initial "WebSessionID,ObjectName" no-undo get.
        protected set.

    define public override property foreignKeys as character
        initial "" no-undo get.
        protected set.

    define public override property mappingType as character
        initial "AFP" no-undo get.
        protected set.

    define public override property capabilities as character
        initial "filter,id,orderBy,skip,sort,top" no-undo get.
        protected set.

    define public override property operations as character
        initial "ReadOnly" no-undo get.
        protected set.


    method public override void initialize ( ):
        /* Describe any overrides to the operations to be exposed. */
        Spark.Core.Util.Annotate:describeRead(serviceURI, getClassName(), "ReadWebData").

        /* Describe any properties to be added the entity tables. */
        define variable oFieldProps as FieldInfo no-undo.
        assign oFieldProps = new FieldInfo("dsWebDataStore", "ttWebDataStore").
        oFieldProps:addProperty("WebSessionID", "editable", false).
        oFieldProps:addProperty("ObjectName", "editable", false).
        Spark.Core.Util.Annotate:describeFields(oFieldProps).

        delete object oFieldProps no-error.
    end method. /* initialize */


    constructor public WebData ( ):
        ProDataSet = dataset dsWebDataStore:handle.

        /* Data Source for each table in dataset. Should be in table order as defined in DataSet */
        extent(DataSourceArray) = 1.
        create data-source DataSourceArray[1].
        DataSourceArray[1]:add-source-buffer(buffer WebDataStore:handle, ?).
        ProDataSource = DataSourceArray.

        /* Skip-list entries for each table in dataset. Should be in temp-table order as defined in DataSet. */
        /* Each skip-list entry is a comma-separated list of field names, to be ignored in create statement. */
        extent(SkipListArray) = 1.
        SkipListArray[1] = "WebSessionID,ObjectName".
        SkipList = SkipListArray.
    end constructor.


    method public void ReadWebData ( input filter as character,
                                     output dataset dsWebDataStore ):
        define variable iNumRecs as int64 no-undo.
        super:ReadData(filter, iNumRecs, output dataset dsWebDataStore by-reference).
    end method. /* ReadWebData */

end class.
