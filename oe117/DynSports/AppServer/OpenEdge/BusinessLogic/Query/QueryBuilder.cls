/* *************************************************************************************************************************
Copyright (c) 2019 by Progress Software Corporation and/or one of its subsidiaries or affiliates. All rights reserved.
************************************************************************************************************************** */
/*------------------------------------------------------------------------
    File        : QueryBuilder
    Purpose     : 
    Syntax      : 
    Description : 
    Author(s)   : pjudge
    Created     : Thu May 10 12:38:00 EDT 2018
    Notes       : ADAS-101
  ----------------------------------------------------------------------*/
block-level on error undo, throw.

using Ccs.BusinessLogic.IGetDataRequest.
using Ccs.BusinessLogic.IQueryEntry.
using OpenEdge.BusinessLogic.* from propath.
using OpenEdge.BusinessLogic.Filter.* from propath.

class OpenEdge.BusinessLogic.Query.QueryBuilder: 

    method protected handle getFieldBuffer (input phTable     as handle,
                                            input pcFieldName as character):
        define variable bhField as handle  no-undo.
        define variable ix      as integer no-undo.

        /* Return the datatype of the field, if it exists in the table. */
        if valid-handle(phTable) then do:
            do ix = 1 to phTable:num-fields:
                assign bhField = phTable:buffer-field(ix) no-error.
                /* Web-based field matches real name or serialized name. */
                if valid-handle(bhField) then do:
                    if bhField:name eq pcFieldName or
                       bhField:serialize-name eq pcFieldName then
                        return bhField.
                    else
                        delete object bhField no-error.
                end. /* valid-handle */
            end. /* do ix */
        end. /* valid-handle */

        return ?. /* Return ? to indicate field is not in temp-table. */

        finally:
            delete object bhField no-error.
        end finally.
    end method. /* getFieldBuffer */

    method private character getMapping ( input pcOperator as character,
                                          input pcDataType as character ):
        /* http://docs.telerik.com/kendo-ui/api/javascript/data/datasource#configuration-filter.operator */
        define variable cTemplate as character no-undo.

        case pcOperator:
            when "eq" then
                if pcDataType eq "character" then
                    assign cTemplate = '&1 eq "&2"'.
                else
                    assign cTemplate = '&1 eq &2'.
            when "neq" then
                if pcDataType eq "character" then
                    assign cTemplate = '&1 ne "&2"'.
                else
                    assign cTemplate = '&1 ne &2'.
            when "lt" then
                assign cTemplate = '&1 lt &2'.
            when "lte" then
                assign cTemplate = '&1 le &2'.
            when "gt" then
                assign cTemplate = '&1 gt &2'.
            when "gte" then
                assign cTemplate = '&1 ge &2'.
            when "begins" or
            when "startswith" then
                assign cTemplate = '&1 begins "&2"'.
            when "contains" then
                assign cTemplate = '&1 matches "*&2*"'.
            when "doesnotcontain" then
                assign cTemplate = 'not (&1 matches "*&2*")'.
            when "endswith" then
                assign cTemplate = '&1 matches "&2"'. /* Value should already be prepended with '*'. */
            otherwise
                undo, throw new Progress.Lang.AppError(substitute("Unknown operator '&1' for filter.", pcOperator), 0).
        end.

        return cTemplate.
    end method. /* getMapping */

    method private character buildClause (input phTable  as handle,
                                          input poClause as QueryPredicate ):
        define variable hField   as handle     no-undo.
        define variable cClause  as character  no-undo.
        define variable cField   as character  no-undo.
        define variable cOper    as character  no-undo.
        define variable cType    as character  no-undo.

        /* http://docs.telerik.com/kendo-ui/api/javascript/data/datasource#configuration-filter.field */
        assign
            hField  = this-object:getFieldBuffer(phTable, poClause:FieldName)
            cOper   = poClause:Operator:ToString()
            no-error.

        if not valid-handle(hField) then return "".

        assign
            cField = hField:name
            cType  = hField:data-type
            no-error.

        /* http://docs.telerik.com/kendo-ui/api/javascript/data/datasource#configuration-filter.value */
        case cType:
            when "character" then
                assign cClause = substitute(this-object:getMapping(cOper, cType),
                                            cField, string(poClause:Value)).
            when "date" then
                assign cClause = substitute(this-object:getMapping(cOper, cType),
                                            cField, date(string(poClause:Value))).
            when "datetime" then
                assign cClause = substitute(this-object:getMapping(cOper, cType),
                                            cField, datetime(string(poClause:Value))).
            when "datetime-tz" then
                assign cClause = substitute(this-object:getMapping(cOper, cType),
                                            cField, datetime-tz(string(poClause:Value))).
            when "decimal" then
                assign cClause = substitute(this-object:getMapping(cOper, cType),
                                            cField, decimal(poClause:Value)).
            when "integer" then
                assign cClause = substitute(this-object:getMapping(cOper, cType),
                                            cField, integer(poClause:Value)).
            when "logical" then
                assign cClause = substitute(this-object:getMapping(cOper, cType),
                                            cField, logical(poClause:Value)).
        end.

        return cClause.
    end method. /* buildClause */

    /* Builds a query handle (object) from a IGetDataRequest object. This method maps
       the input names to the input handle's SERIALIZE-NAMEs and uses the 'real'
       names to build the where clause
       
       @param IGetDataRequest A valid queryn definition
       @param handle a Dataset or buffer (TT or DB) handle 
       @return handle A valid QUERY handle */
    method public handle BuildQuery (input pFilter as IGetDataRequest,
                                     input pSchema as handle):
    end method.
    
    /* Builds a query string from a IGetDataRequest object. This method does
       no name conversions - just takes the names from the input object.
       
       @param IGetDataRequest A valid queryn definition
       @return character A complete WHERE clause , with no name conversions */
    method public character BuildQueryString (input pFilter as IGetDataRequest):
        return BuildQueryString(pFilter, ?).
    end method.
    
    /* Builds a query string from a IGetDataRequest object. This method maps
       the input names to the input handle's SERIALIZE-NAMEs and uses the 'real'
       names to build the where clause
       
       @param IGetDataRequest A valid queryn definition
       @param handle a Dataset or buffer (TT or DB) handle 
       @return character A complete WHERE clause */
    method public character BuildQueryString (input pFilter as IGetDataRequest,
                                              input pSchema as handle):
        define variable oQueryDef     as QueryDefinition no-undo.
        define variable cQueryString  as character       no-undo initial "".
        define variable oQueryEntries as IQueryEntry     no-undo extent.
        define variable oSortList     as QuerySortEntry  no-undo extent.
        define variable bhTable       as handle          no-undo.
        define variable bhField       as handle          no-undo.
        define variable iLoop         as integer         no-undo.
        define variable cJoin         as character       no-undo.
        define variable cSortBy       as character       no-undo.

        if valid-handle(pSchema) then
            assign bhTable = pSchema:get-buffer-handle(1) no-error. /* Get the top table. */
        else
            undo, throw new Progress.Lang.AppError("Invalid or unset handle to ProDataSet.").
message "DS:" pSchema:name.
message "TT:" bhTable:name.

        assign oQueryDef = cast(pFilter:TableRequests[1]:QueryDefinition, QueryDefinition).
        assign oSortList = cast(oQueryDef:QuerySort, QuerySortEntry).

        if type-of(oQueryDef:QuerySelection, QueryGroup) then do:
            assign oQueryEntries = cast(oQueryDef:QuerySelection, QueryGroup):Entries.
            assign cJoin = cast(oQueryDef:QuerySelection, QueryGroup):join:ToString().

            if extent(oQueryEntries) ne ? and extent(oQueryEntries) ge 1 then
            do iLoop = 1 to extent(oQueryEntries):
                assign cQueryString = this-object:buildClause(bhTable, cast(oQueryEntries[iLoop], QueryPredicate)).
            end.
        end.
        else if type-of(oQueryDef:QuerySelection, QueryPredicate) then do:
            assign cQueryString = this-object:buildClause(bhTable, cast(oQueryDef:QuerySelection, QueryPredicate)).
        end.
message "QueryString:" cQueryString.

        if extent(oSortList) ne ? then
        do iLoop = 1 to extent(oSortList):
            if valid-object(oSortList[iLoop]) then do:
                assign bhField = getFieldBuffer(bhTable, oSortList[iLoop]:FieldName).
                if valid-object(bhField) then
                    assign cSortBy = trim(substitute("&1 by &2 &3", cSortBy, bhField:name,
                                                     if oSortList[iLoop]:SortOrder eq Ccs.BusinessLogic.SortOrderEnum:Ascending
                                                     then "" else oSortList[iLoop]:SortOrder:ToString())).
            end. /* Valid Sort Entry*/
        end. /* do iLoop */

        if trim(cQueryString) eq "" then
            assign cQueryString = "where true".

        if not cQueryString begins "where" then
            assign cQueryString = substitute("where &1", cQueryString).

        assign cQueryString = substitute("&1 &2", cQueryString, cSortBy).
message "Query:" cQueryString.

        return trim(cQueryString).
    end method.
    
end class.