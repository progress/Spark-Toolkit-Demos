/*------------------------------------------------------------------------
    File        : EmployeeBE.cls
    Author(s)   : Code Wizard
    Created     : 03/01/16
    Notes       : Customized BE instance with AFP features available.
  ----------------------------------------------------------------------*/

using Progress.Lang.* from propath.
using Spark.Core.Util.FieldInfo from propath.
using Spark.Core.Util.ForeignKey from propath.

block-level on error undo, throw.

class Business.Personnel.EmployeeBE inherits Spark.Core.Service.DynamicEntity use-widget-pool:

    {Common/employee.i}

    define public override property serviceURI as character
        initial "/web/api/personnel" no-undo get.
        protected set.

    define public override property resourceName as character
        initial "employee" no-undo get.
        protected set.

    define public override property primaryKeys as character
        initial "ttEmployee.EmpNum" no-undo get.
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
        initial "ReadOnly,Submit" no-undo get.
        protected set.


    method public override void initialize ( ):
        /* Describe any overrides to the operations to be exposed. */
        Spark.Core.Util.Annotate:describeRead(serviceURI, getClassName(), "ReadEmployee").
        Spark.Core.Util.Annotate:describeSubmit(serviceURI, getClassName(), "SubmitEmployee").
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "getCount", "count", "get").

        /* Describe any properties to be added the entity tables. */
        define variable oFieldProps as FieldInfo no-undo.
        assign oFieldProps = new FieldInfo("dsEmployee", "ttEmployee").
        oFieldProps:addProperty("seq", "semanticType", "Internal").
        Spark.Core.Util.Annotate:describeFields(oFieldProps).
        delete object oFieldProps no-error.
    end method. /* initialize */


    constructor public EmployeeBE ( ):
        ProDataSet = dataset dsEmployee:handle.

        /* Data Source for each table in dataset. Should be in table order as defined in DataSet */
        extent(DataSourceArray) = 1.
        create data-source DataSourceArray[1].
        DataSourceArray[1]:add-source-buffer(buffer Employee:handle, ?).
        ProDataSource = DataSourceArray.

        /* Skip-list entries for each table in dataset. Should be in temp-table order as defined in DataSet. */
        /* Each skip-list entry is a comma-separated list of field names, to be ignored in create statement. */
        extent(SkipListArray) = 1.
        SkipListArray[1] = "".
        SkipList = SkipListArray.
    end constructor.


    method public void ReadEmployee ( input  filter  as character,
                                      output dataset dsEmployee ):
        define variable iNumRecs as int64 no-undo.
        super:ReadData(filter, iNumRecs, output dataset dsEmployee by-reference).
    end method. /* ReadEmployee */


    method public void SubmitEmployee ( input-output dataset dsEmployee ):
        super:SubmitData(input-output dataset dsEmployee by-reference).
    end method. /* SubmitEmployee */

end class.
