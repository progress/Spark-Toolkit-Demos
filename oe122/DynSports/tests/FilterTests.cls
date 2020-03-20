/*------------------------------------------------------------------------
    File        : FilterTests
    Purpose     :
    Description :
    Author(s)   : pjudge & dugrau
    Created     : Mon Jun 18 10:05:30 EDT 2018
    Notes       :
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

using Ccs.BusinessLogic.* from propath.
using OpenEdge.BusinessLogic.Filter.* from propath.
using OpenEdge.BusinessLogic.Query.* from propath.
using OpenEdge.Core.String from propath.
using Progress.Lang.* from propath.
using Progress.Json.ObjectModel.* from propath.

block-level on error undo, throw.

class tests.FilterTests:

    /* Schema for testing of the QueryBuilder */

    define temp-table ttCustomer no-undo serialize-name "customer" before-table bttCustomer
        field id      as character
        field seq     as integer   initial ?
        field CustNum as integer   label "Cust Num" initial 0
        field Name    as character label "Name" serialize-name "CustName"
        index pkSeq   is primary unique seq
        .
    define dataset dsCustomer for ttCustomer.

    /* Common Variables */

    define private variable oFilterBuilder as FilterParserBuilder no-undo.
    define private variable oFilterParser  as FilterParser        no-undo.
    define private variable oDataRequest   as IGetDataRequest     no-undo.
    define private variable oSortEntry     as IQuerySortEntry     no-undo.
    define private variable oParser        as ObjectModelParser   no-undo.
    define private variable oFilterList    as JsonArray           no-undo.
    define private variable oFilterData    as JsonObject          no-undo.
    define private variable oABLFilter     as JsonArray           no-undo.
    define private variable oQueryBuilder  as QueryBuilder        no-undo.
    define private variable cFullQuery     as character           no-undo format "x(300)".
    define private variable cLogFile       as character           no-undo.
    define private variable cPattern       as character           no-undo format "x(32)".
    define private variable cTable         as character           no-undo format "x(32)".
    define private variable cQuery         as character           no-undo format "x(250)".
    define private variable iSkip          as integer             no-undo initial 100.
    define private variable iTop           as integer             no-undo initial 25.
    define private variable iX             as integer             no-undo.
    define private variable iY             as integer             no-undo.

    method private void showOutput ( input pcTestName as character ):
        output to value(cLogFile) append.
        put unformatted "Test: " pcTestName skip.

        cPattern = oFilterBuilder:FilterPattern.
        put unformatted "Pattern: " cPattern skip.

        /* Cycle through each table request to show the data extracted. */
        do iX = 1 to extent(oDataRequest:TableRequests[1]):
            cTable = oDataRequest:TableRequests[iX]:TableName.
            put unformatted "Table" trim(string(iX)) ": " cTable skip.
            put unformatted "SkipRec: " oDataRequest:TableRequests[iX]:Skip skip.
            put unformatted "Records: " oDataRequest:TableRequests[iX]:NumRecords skip.
            put unformatted "Context: " oDataRequest:TableRequests[iX]:PagingContext skip.

            if valid-object(oDataRequest:TableRequests[iX]:QueryDefinition) then do:
                cQuery = oDataRequest:TableRequests[iX]:QueryDefinition:ToString().
                put unformatted "QueryDef: " cQuery skip.
            end.

            cQuery = oDataRequest:TableRequests[iX]:QueryString.
            put unformatted "QueryStr: " cQuery skip.
        end.

        put unformatted skip "FullQuery: " cFullQuery skip(2).

        output close.
    end method.

    @Before.
    method public void before ( ):
        assign oParser = new ObjectModelParser().
        assign oQueryBuilder = new QueryBuilder().

        /* Set output location for any messages, if not specified. */
        if log-manager:logfile-name eq ? then
            log-manager:logfile-name = "server.log".

        /* Output location for the raw test results. */
        cLogFile = substitute("tests/filter_&1.log", mtime).

        /* Load an array with all of the potential test cases. */
        oABLFilter = new JsonArray().
        oABLFilter:Add("WHERE CustNum <>42").
        oABLFilter:Add("WHERE CustNum<> 42").
        oABLFilter:Add("WHERE CustNum <> 42").
        oABLFilter:Add('WHERE Name begins "abc"').
        oABLFilter:Add('WHERE Name="abc"').
        oABLFilter:Add('WHERE Name="ab~'c"').
        oABLFilter:Add("WHERE Name='a~"bc'").
        oABLFilter:Add("WHERE ((CustNum <> 42) and Name ne ?))").

        /* Create a JSON object for use with additional examples. */
        oFilterData = new JsonObject().
        oFilterData:Add("ablFilter", oABLFilter:GetCharacter(3)). /* Use a specific query. */
        oFilterData:Add("orderBy", "CustNum desc, SalesRep"). /* Set a custom sort order. */
        oFilterData:Add("top", iTop).
        oFilterData:Add("skip", iSkip).
        oFilterData:Add("id", "0xabc123").
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Option 1 - Plain String
        Notes: Pattern name or phrase; lets the parser builder figure this out.
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testPlainString ( ):
        oFilterBuilder = FilterParserBuilder:Build("WHERE").
        oFilterParser = oFilterBuilder:Parser.
        oDataRequest = oFilterParser:Parse(new String(oABLFilter:GetCharacter(3))).

        /* Test with a simple "where" phrase and its output. */
        OpenEdge.Core.Assert:Equals(oFilterBuilder:FilterPattern, "WHERE").
        assign cFullQuery = oQueryBuilder:BuildQueryString(oDataRequest, dataset dsCustomer:handle).
        this-object:showOutput("Option1a").
        OpenEdge.Core.Assert:Equals(cFullQuery, 'each ttCustomer where CustNum ne 42').

        oFilterBuilder = FilterParserBuilder:Build("JFP").
        oFilterParser = oFilterBuilder:Parser.
        oDataRequest = oFilterParser:Parse(new String(oABLFilter:GetCharacter(3))).

        /* Test with just the "JFP" pattern and its output. */
        OpenEdge.Core.Assert:Equals(oFilterBuilder:FilterPattern, "JFP").
        assign cFullQuery = oQueryBuilder:BuildQueryString(oDataRequest, dataset dsCustomer:handle).
        this-object:showOutput("Option1b").
        OpenEdge.Core.Assert:Equals(cFullQuery, 'each ttCustomer where CustNum ne 42').
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Option 2 - JSON Array
        Notes: Iterates until an object or string creates a valid builder.
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testJsonArray ( ):
        oFilterList = new JsonArray().
        oFilterList:Add(oFilterData).
        oFilterBuilder = FilterParserBuilder:Build(oFilterList).
        oFilterParser = oFilterBuilder:Parser.
        oDataRequest = oFilterParser:Parse(oFilterList:GetJsonObject(1)).

        /* Test with the "ablFilter" pattern and its output. */
        OpenEdge.Core.Assert:Equals(oFilterBuilder:FilterPattern, "ablFilter").
        assign cFullQuery = oQueryBuilder:BuildQueryString(oDataRequest, dataset dsCustomer:handle).
        this-object:showOutput("Option2").
        OpenEdge.Core.Assert:Equals(cFullQuery, 'each ttCustomer where CustNum ne 42 by CustNum Descending by SalesRep').
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Option 3 - JSON Object
        Notes: Iterates until an object or string creates a valid builder.
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testJsonObject ( ):
        oFilterBuilder = FilterParserBuilder:Build(oFilterData).
        oFilterParser = oFilterBuilder:Parser.
        oDataRequest = oFilterParser:Parse(oFilterData).

        /* Test with the "ablFilter" pattern and its output. */
        OpenEdge.Core.Assert:Equals(oFilterBuilder:FilterPattern, "ablFilter").
        assign cFullQuery = oQueryBuilder:BuildQueryString(oDataRequest, dataset dsCustomer:handle).
        this-object:showOutput("Option3a").
        OpenEdge.Core.Assert:Equals(cFullQuery, 'each ttCustomer where CustNum ne 42 by CustNum Descending by SalesRep').

        define variable cPayload as character no-undo.

        /* Test with the "kendo" pattern and its output (requires some additional setup). */
        assign cPayload = substitute('~{"mappingType": "kendo", "filter": ~{"logic": "and", "filters": [~{"field": "CustNum", "operator": "ne", "value": 42}]}, "sort": [~{"field": "CustNum", "dir": "desc"}, ~{"field": "SalesRep", "dir": "asc"}], "skip": &1, "top": &2}', iSkip, iTop).
        oFilterData = cast(oParser:Parse(cPayload), JsonObject).
        oFilterBuilder = FilterParserBuilder:Build(oFilterData).
        oFilterBuilder:TableName("ttCustomer"). /* Let the parser know the temp-table name if we know it. */
        oFilterParser = oFilterBuilder:Parser.
        oDataRequest = oFilterParser:Parse(oFilterData).

        OpenEdge.Core.Assert:Equals(oFilterBuilder:FilterPattern, "kendo").
        assign cFullQuery = oQueryBuilder:BuildQueryString(oDataRequest, dataset dsCustomer:handle).
        this-object:showOutput("Option3b").
        OpenEdge.Core.Assert:Equals(cFullQuery, 'each ttCustomer where (CustNum ne 42) by CustNum Descending by SalesRep').

        /* Test with the "kendo" pattern and its output (requires some additional setup). */
        assign cPayload = substitute('~{"mappingType": "kendo", "filter": ~{"logic": "and", "filters": [~{"field": "CustNum", "operator": "gt", "value": 1}, ~{"field": "CustNum", "operator": "lt", "value": 10000}, ~{"logic": "or", "filters": [~{"field": "Name", "operator": "begins", "value": "A"}, ~{"field": "Name", "operator": "begins", "value": "B"}]}]}, "sort": [~{"field": "CustNum", "dir": "desc"}, ~{"field": "SalesRep", "dir": "asc"}], "skip": &1, "top": &2}', iSkip, iTop).
        oFilterData = cast(oParser:Parse(cPayload), JsonObject).
        oFilterBuilder = FilterParserBuilder:Build(oFilterData).
        oFilterBuilder:TableName("ttCustomer"). /* Let the parser know the temp-table name if we know it. */
        oFilterParser = oFilterBuilder:Parser.
        oDataRequest = oFilterParser:Parse(oFilterData).

        OpenEdge.Core.Assert:Equals(oFilterBuilder:FilterPattern, "kendo").
        assign cFullQuery = oQueryBuilder:BuildQueryString(oDataRequest, dataset dsCustomer:handle).
        this-object:showOutput("Option3c").
        OpenEdge.Core.Assert:Equals(cFullQuery, 'each ttCustomer where (CustNum gt 1) and (CustNum lt 10000) and ((Name begins "A") or (Name begins "B")) by CustNum Descending by SalesRep').
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Serialized Field Name
        Notes: Attempt to create matching queries from real/serialized field name.
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testSerializedField ( ):
        define variable cPayload as character no-undo.

        /* Test with the "kendo" pattern using a direct temp-table field name. */
        assign cPayload = substitute('~{"mappingType": "kendo", "filter": ~{"logic": "and", "filters": [~{"field": "Name", "operator": "eq", "value": "Test"}]}, "skip": &1, "top": &2}', iSkip, iTop).
        oFilterData = cast(oParser:Parse(cPayload), JsonObject).
        oFilterBuilder = FilterParserBuilder:Build(oFilterData).
        oFilterBuilder:TableName("ttCustomer"). /* Give the parser a known temp-table name. */
        oFilterParser = oFilterBuilder:Parser.
        oDataRequest = oFilterParser:Parse(oFilterData).

        OpenEdge.Core.Assert:Equals(oFilterBuilder:FilterPattern, "kendo").
        assign cFullQuery = oQueryBuilder:BuildQueryString(oDataRequest, dataset dsCustomer:handle).
        this-object:showOutput("RealField").
        OpenEdge.Core.Assert:Equals(cFullQuery, 'each ttCustomer where (Name eq "Test")').

        /* Test with the "kendo" pattern using a serialized temp-table field name. */
        assign cPayload = substitute('~{"mappingType": "kendo", "filter": ~{"logic": "and", "filters": [~{"field": "CustName", "operator": "eq", "value": "Test"}]}, "skip": &1, "top": &2}', iSkip, iTop).
        oFilterData = cast(oParser:Parse(cPayload), JsonObject).
        oFilterBuilder = FilterParserBuilder:Build(oFilterData).
        oFilterBuilder:TableName("ttCustomer"). /* Give the parser a known temp-table name. */
        oFilterParser = oFilterBuilder:Parser.
        oDataRequest = oFilterParser:Parse(oFilterData).

        OpenEdge.Core.Assert:Equals(oFilterBuilder:FilterPattern, "kendo").
        assign cFullQuery = oQueryBuilder:BuildQueryString(oDataRequest, dataset dsCustomer:handle).
        this-object:showOutput("SerializedField").
        OpenEdge.Core.Assert:Equals(cFullQuery, 'each ttCustomer where (Name eq "Test")').
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Serialized Table Name
        Notes: Attempt to create matching queries from serialized table name.
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testSerializedTable ( ):
        define variable cPayload as character no-undo.

        /* Test with the "kendo" pattern using a serialized temp-table name. */
        assign cPayload = substitute('~{"mappingType": "kendo", "filter": ~{"logic": "and", "filters": [~{"field": "CustName", "operator": "eq", "value": "Test"}]}, "skip": &1, "top": &2}', iSkip, iTop).
        oFilterData = cast(oParser:Parse(cPayload), JsonObject).
        oFilterBuilder = FilterParserBuilder:Build(oFilterData).
        oFilterBuilder:TableName("customer"). /* Give the parser a serialized temp-table name. */
        oFilterParser = oFilterBuilder:Parser.
        oDataRequest = oFilterParser:Parse(oFilterData).

        OpenEdge.Core.Assert:Equals(oFilterBuilder:FilterPattern, "kendo").
        assign cFullQuery = oQueryBuilder:BuildQueryString(oDataRequest, dataset dsCustomer:handle).
        this-object:showOutput("SerializedTable").
        OpenEdge.Core.Assert:Equals(cFullQuery, 'each ttCustomer where (Name eq "Test")').
    end method.

end class.
