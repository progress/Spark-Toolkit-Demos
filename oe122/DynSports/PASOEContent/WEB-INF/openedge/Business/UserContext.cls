/*------------------------------------------------------------------------
    File        : WebContext.cls
    Purpose     : Simple class for User context data
    Author(s)   : Dustin Grau (dugrau@progress.com)
    Created     : 02/21/18
    Notes       :
  ----------------------------------------------------------------------*/

using Progress.Lang.* from propath.
using Progress.Json.ObjectModel.* from propath.

block-level on error undo, throw.

class Business.UserContext inherits Spark.Core.Service.DynamicEntity use-widget-pool:

    {Common/webcontext.i}

    define public override property serviceURI as character
        initial "/web/api/common" no-undo get.
        protected set.

    define public override property resourceName as character
        initial "context" no-undo get.
        protected set.

    define public override property primaryKeys as character
        initial "IdentityName,ContextType,ContextViewID,ContextTitle,ContextSeqNo" no-undo get.
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
        Spark.Core.Util.Annotate:describeRead(serviceURI, getClassName(), "ReadContext").
        Spark.Core.Util.Annotate:describeSubmit(serviceURI, getClassName(), "SubmitContext").
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "getCount", "count", "get").
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "clearContext", "clear", "put").
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "getRoles", "roles", "put").
    end method. /* initialize */


    constructor public UserContext ( ):
        ProDataSet = dataset dsWebContext:handle.

        /* Data Source for each table in dataset. Should be in table order as defined in DataSet */
        extent(DataSourceArray) = 1.
        create data-source DataSourceArray[1].
        DataSourceArray[1]:add-source-buffer(buffer WebContext:handle, ?).
        ProDataSource = DataSourceArray.

        /* Skip-list entries for each table in dataset. Should be in temp-table order as defined in DataSet. */
        /* Each skip-list entry is a comma-separated list of field names, to be ignored in create statement. */
        extent(SkipListArray) = 1.
        SkipListArray[1] = "".
        SkipList = SkipListArray.
    end constructor.


    method protected override character validateData ( input pcAction as character,
                                                       input-output dataset-handle phDataset ):
        define variable bhTopTable as handle  no-undo.
        define variable bhBefore   as handle  no-undo.
        define variable hQuery     as handle  no-undo.
        define variable lAvail     as logical no-undo.
        define variable iBuffers   as integer no-undo.
        define variable ix         as integer no-undo.
        define variable iy         as integer no-undo.

        if not valid-handle(phDataset) then return "".

        assign iBuffers = phDataset:num-top-buffers.
        do ix = 1 to iBuffers:
            assign bhTopTable = phDataset:get-top-buffer(ix).
            bhTopTable:table-handle:tracking-changes = true.
            assign bhBefore = bhTopTable:before-buffer.

            create query hQuery.
            hQuery:set-buffers(bhBefore).
            hQuery:query-prepare(substitute('FOR EACH &1', bhBefore:name)).
            hQuery:query-open().
            assign lAvail = hQuery:get-first(no-lock).

            VALIDATEBLK:
            do while lAvail:
                if bhBefore:row-state eq row-deleted then do:
                    /* This will return an error (as HTTP 405) to indicate delete is not allowed. */
                    undo, throw new OpenEdge.Web.SendExceptionError(OpenEdge.Net.HTTP.StatusCodeEnum:MethodNotAllowed,
                                                                    "Delete operation is not allowed.").

                    /* If delete IS allowed, then this method should return blank. */
                    /* return "". */
                end. /* row-deleted */

                if bhTopTable:find-first(substitute("where rowid(&1) eq to-rowid('&2')", bhTopTable:name, bhBefore:after-rowid)) then
                do iy = 1 to bhTopTable:num-fields:
                    if bhTopTable:row-state eq row-created then do:
                        /* Always assign the current username as the IdentityName field. */
                        if bhTopTable:buffer-field(iy):name eq "IdentityName" then
                            bhTopTable:buffer-field(iy):buffer-value = oClientContext:userID.
                    end. /* row-created */

                    if bhTopTable:row-state eq row-modified then do:
                        /* Always assign the current username as the IdentityName field. */
                        if bhTopTable:buffer-field(iy):name eq "IdentityName" then
                            bhTopTable:buffer-field(iy):buffer-value = oClientContext:userID.
                    end. /* row-modified */
                end. /* table field */
                assign lAvail = hQuery:get-next(no-lock).
            end. /* lAvail */
        end. /* do ix */

        return "".

        finally:
            hQuery:query-close() no-error.
            delete object hQuery no-error.
            delete object bhTopTable no-error.
            delete object bhBefore no-error.
        end finally.
    end method. /* validateData */


    method public void ReadContext ( input  filter  as character,
                                     output dataset dsWebContext ):
        define variable oFilterObj as JsonObject no-undo.
        define variable oFilter    as JsonObject no-undo.
        define variable oFilters   as JsonArray  no-undo.
        define variable oCriteria  as JsonObject no-undo.
        define variable ix         as integer    no-undo.
        define variable lFound     as logical    no-undo.

        assign lFound = false.
        if filter begins "~{" then
            assign oFilterObj = this-object:getFilterObject(filter).
        if valid-object(oFilterObj) then do:
            if oFilterObj:Has("filter") and oFilterObj:Has("client") and
               oFilterObj:GetCharacter("client") eq "KendoUI" then do:
                assign oFilter = oFilterObj:GetJsonObject("filter").
                if valid-object(oFilter) and oFilter:Has("filters") then
                    assign oFilters = oFilter:GetJsonArray("filters").

                if valid-object(oFilters) then
                do ix = 1 to oFilters:length:
                    /* If filters available, look for field "IdentityName". */
                    assign oCriteria = oFilters:GetJsonObject(ix).
                    if oCriteria:Has("field") and oCriteria:GetCharacter("field") eq "IdentityName" then do:
                        assign lFound = true. /* Inbound filter has a filter criteria item for IdentityName. */
                        oCriteria:Set("value", oClientContext:userID). /* Override with the current username. */
                    end. /* found field */
                end. /* do ix = 1 to oFilters:length */
            end. /* oFilterObj:Has("filter") [KendoUI] */
        end. /* valid-object(oFilterObj) */

        if not lFound then do:
            /* Did not find filter criteria by field name, so create it. */
            assign oCriteria = new JsonObject().
            oCriteria:Add("field", "IdentityName").
            oCriteria:Add("operator", "eq").
            oCriteria:Add("value", oClientContext:userID).

            /* Create a filters array if it doesn't exist. */
            if not valid-object(oFilters) then
                assign oFilters = new JsonArray().

            /* Add the new criteria item to the filters list. */
            oFilters:Add(oCriteria).

            /* Create a child filter object if it doesn't exist. */
            if not valid-object(oFilter) then
                assign oFilter = new JsonObject().

            /* Update or create the filters property. */
            if oFilter:Has("filters") then do:
                oFilter:Set("logic", "and").
                oFilter:Set("filters", oFilters).
            end. /* filters exists */
            else do:
                oFilter:Add("logic", "and").
                oFilter:Add("filters", oFilters).
            end. /* doesn't exist */

            /* Create a parent filter object if it doesn't exist. */
            if not valid-object(oFilterObj) then
                assign oFilterObj = new JsonObject().

            /* Update or create the filter property. */
            if oFilterObj:Has("filter") then
                oFilterObj:Set("filter", oFilter).
            else do:
                oFilterObj:Add("client", "KendoUI").
                oFilterObj:Add("filter", oFilter).
            end.
        end. /* not lFound */

        /* Return altered filter from adjusted JSON object. */
        assign filter = oFilterObj:GetJsonText().

        define variable iNumRecs as int64 no-undo.
        super:ReadData(filter, iNumRecs, output dataset dsWebContext by-reference).
    end method. /* ReadContext */


    method public void SubmitContext ( input-output dataset dsWebContext ):
        super:SubmitData(input-output dataset dsWebContext by-reference).
    end method. /* SubmitContext */


    method public void getCount ( input filter as character, output numRecs as int64 ):
        assign numRecs = this-object:getRecCount(filter).
    end method. /* getCount */


    method public void clearContext ( input  contextType    as character,
                                      input  contextViewID  as character,
                                      input  contextTitle   as character,
                                      output clearedRecords as integer ):
        define buffer bContext for WebContext.

        for each bContext exclusive-lock
           where bContext.IdentityName eq oClientContext:userID
             and (contextType eq "" or bContext.ContextType eq contextType)
             and (contextViewID eq "" or bContext.ContextViewID eq contextViewID)
             and (contextTitle eq "" or bContext.ContextTitle eq contextTitle):
            message substitute("Deleting context for &1 &2 &3 &4", contextType, contextViewID, contextTitle, contextSeqNo).
            delete bContext. /* Delete matching record. */
            assign clearedRecords = clearedRecords + 1.
        end. /* for each */
    end method. /* clearContext */


    method public void getRoles ( input  clientID     as character,
                                  output allowedRoles as JsonArray ):
        define variable cRoles as character no-undo.
        define variable iX     as integer   no-undo.

        allowedRoles = new JsonArray(). /* Set to empty array. */

        if valid-object(oClientContext) then do:
            assign cRoles = oClientContext:clientPrincipal:roles.
            do iX = 1 to num-entries(cRoles):
                allowedRoles:Add(substitute("&1:&2", clientID, substring(entry(iX, cRoles), 6))).
            end. /* iX */
        end. /* valid-object */
    end method. /* getRoles */

end class.
