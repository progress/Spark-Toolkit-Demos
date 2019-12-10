/* *************************************************************************************************************************
Copyright (c) 2018 by Progress Software Corporation and/or one of its subsidiaries or affiliates. All rights reserved.
************************************************************************************************************************** */
/*------------------------------------------------------------------------
    File        : CloudDataObjectCatalogWriter
    Purpose     : Writes a DataObjectService as a JSDO-compatible catalog
    Syntax      :
    Description :
    Author(s)   : dgrau
    Created     : 2019-12-09
    Notes       : - https://github.com/progress/CDO/blob/master/CloudDataObject_Catalog.pdf
  ----------------------------------------------------------------------*/
block-level on error undo, throw.

using OpenEdge.Core.Collections.IIterator.
using OpenEdge.Core.SemanticVersion.
using OpenEdge.Net.HTTP.HttpHeader.
using OpenEdge.Net.HTTP.MethodEnum.
using OpenEdge.Net.URI.
using OpenEdge.Web.DataObject.DataObjectService.
using OpenEdge.Web.DataObject.ElementTypeEnum.
using OpenEdge.Web.DataObject.MappedOperation.
using OpenEdge.Web.DataObject.MessageElement.
using OpenEdge.Web.DataObject.OperationParameter.
using OpenEdge.Web.DataObject.TargetTypeEnum.
using OpenEdge.Web.DataObject.Writer.DataObjectServiceWriter.
using Progress.Json.ObjectModel.JsonArray.
using Progress.Json.ObjectModel.JsonObject.

class Spark.Core.Handler.CloudDataObjectCatalogWriter inherits DataObjectServiceWriter:

    define static public property CATALOG_VERSION as decimal no-undo
        get.
        private set.

    constructor static CloudDataObjectCatalogWriter ( ):
        assign CATALOG_VERSION = 1.5.
    end constructor.

    /* Default constructor */
    constructor public CloudDataObjectCatalogWriter ( ):
        super (get-class(JsonObject)).
    end constructor.

    method override public void open ( ):
        // If nothing's passed in, create an instance of the Argument Type.
        if not valid-object(this-object:Value) then
            assign this-object:Value = WriteServiceRoot().

        super:Open().
    end method.

    method protected JsonObject WriteServiceRoot ( ):
        define variable catJson as JsonObject no-undo.

        assign catJson = new JsonObject().

        catJson:Add('version':u, CATALOG_VERSION).  // REQUIRED. This string must be the semantic version number of the catalog.
        catJson:Add('lastModified':u, now).         // REQUIRED. Timestamp for when this catalog data was generated.
        catJson:Add('services':u, new JsonArray()). // REQUIRED. The available services which have been defined.

        return catJson.
    end method. /* WriteServiceRoot */

    method protected JsonObject GetServiceJson ( input cServiceName as character ):
        define variable svcsJson as JsonArray no-undo.
        define variable iCnt     as integer   no-undo.
        define variable ix       as integer   no-undo.

        assign
            svcsJson = cast(this-object:Value, JsonObject):GetJsonArray('services':u)
            iCnt     = svcsJson:Length
            .

        do iX = 1 to iCnt:
            if svcsJson:GetJsonObject(iX):Has('name':u) and
               svcsJson:GetJsonObject(iX):GetCharacter('name':u) eq cServiceName then do:
                return svcsJson:GetJsonObject(iX).
            end.
        end.
    end method.

    method override protected void WriteService ( input pData as DataObjectService ):
        define variable svcJson as JsonObject no-undo.
        define variable setJson as JsonObject no-undo.

        if pData:Name eq DataObjectService:ROOT_SERVICE_NAME then return.
        if not valid-object(pData:Options) then return.

        assign svcJson = GetServiceJson(pData:Name).
        if not valid-object(svcJson) then do:
            /* Create the new service if not already present. */
            assign svcJson = new jsonObject().
            svcJson:Add('name':u,      pData:Name).
            svcJson:Add('address':u,   substitute('&1/&2':u, cast(pData:Options, Spark.Core.Handler.ServiceOptions):PrefixURI, pData:Name)).

            assign setJson = new JsonObject().
            setJson:Add('useRequest':u,      false).
            setJson:Add('sendOnlyChanges':u, false).
            setJson:Add('unwrapped':u,       false).
            setJson:Add('useXClientProps':u, false).

            svcJson:Add('settings':u, setJson).
            svcJson:Add('resources':u, new JsonArray()).

            cast(this-object:Value, JsonObject):GetJsonArray('services':u):Add(svcjson).
        end.
    end method.

    method override protected void WriteOperation ( input pService as DataObjectService,
                                                    input pMapOp   as MappedOperation ):
        define variable serviceObj  as JsonObject no-undo.
        define variable resourceArr as JsonArray  no-undo.
        define variable resource    as JsonObject no-undo.
        define variable operation   as JsonObject no-undo.
        define variable childObj    as JsonObject no-undo.
        define variable schemaJson  as JsonObject no-undo.
        define variable paramArr    as JsonArray  no-undo.
        define variable iter        as IIterator  no-undo.
        define variable cResource   as character  no-undo.
        define variable fldType     as character  no-undo.
        define variable fldFormat   as character  no-undo.
        define variable iCnt        as integer    no-undo.
        define variable iX          as integer    no-undo.
        define variable operSchema  as handle     no-undo.
        define variable opParam     as OperationParameter no-undo.

        if pMapOp:name eq '':u then return. /* Can't proceed if there is no operation name. */

        assign serviceObj = this-object:GetServiceJson(pService:Name).
        if valid-object(serviceObj) and serviceObj:Has('resources':u) then
            assign resourceArr = serviceObj:GetJsonArray('resources':u).

        assign
            cResource = entry(1, left-trim(pMapOp:ServiceURI, '~/':u), '~/':u)
            iCnt      = resourceArr:Length
            .

        do iX = 1 to iCnt:
            if resourceArr:GetJsonObject(iX):GetCharacter('name':u) eq cResource then
                assign resource = resourceArr:GetJsonObject(iX).
        end.

        if not valid-object(resource) then do:
            assign resource  = new JsonObject().
            resource:Add('name':u, cResource).
            resource:Add('path':u, substitute('/&1':u, cResource)).
            resource:Add('autoSave':u, false).
            resource:Add('displayName':u, cResource).
            resource:Add('schema':u, new JsonObject()).
            resource:GetJsonObject('schema':u):Add('type':u, 'object':u).
            resource:GetJsonObject('schema':u):Add('additionalProperties':u, false).
            resource:GetJsonObject('schema':u):Add('properties':u, new JsonObject()).
            resource:Add('relations':u, new JsonArray()).
            resource:Add('operations':u, new JsonArray()).
            resource:Add('dataDefinitions':u, new JsonObject()).
            resourceArr:Add(resource).
        end.

        assign operation = new JsonObject().
        operation:Add('name':u, pMapOp:name).
        operation:Add('path':u, substring(pMapOp:ServiceURI, length(cResource) + 2)).

        if pMapOp:name eq "read" then do:
            operation:Set('path':u, '?filter=~{filter~}':u).
            operation:Add('capabilities':u, 'filter,id,orderBy,skip,sort,top':u).
            operation:Add('mappingType':u, 'AFP':u).
            operation:Add('useBeforeImage':u, true).
            operation:Add('type':u, 'read':u).
        end.
        else if can-do("create,update,delete,submit", pMapOp:name) then do:
            operation:Add('useBeforeImage':u, true).
            operation:Add('type':u, pMapOp:name).
        end.
        else do:
            operation:Add('useBeforeImage':u, false).
            operation:Add('type':u, 'invoke':u).
        end.

        operation:Add('verb':u, lc(string(pMapOp:Method))).

        assign
            iter     = pMapOp:Parameters:Iterator()
            paramArr = new JsonArray()
            .

        do while iter:HasNext():
            assign opParam = cast(iter:Next(), OperationParameter).

            assign childObj = new JsonObject().
            case opParam:IOMode:
                when OpenEdge.Core.IOModeEnum:Input or
                when OpenEdge.Core.IOModeEnum:Input-by-reference then do:
                    childObj:Add('mode':u, 'Input':u).
                    childObj:Add('name':u, opParam:ABLName).
                    if opParam:IsArray then
                        childObj:AddNull('extent':u).
                    else
                        childObj:Add('extent':u, 0).
                    childObj:Add('xType':u, if num-entries(opParam:ABLType, ' ':u) eq 2 then entry(2, opParam:ABLType, ' ':u) else opParam:ABLType).
                    if pMapOp:name eq "read" then
                        childObj:Add('type':u, 'QUERY':u).
                    else
                        childObj:Add('type':u, 'REQUEST_BODY':u).
                end.

                when OpenEdge.Core.IOModeEnum:Input-Output or
                when OpenEdge.Core.IOModeEnum:Input-Output-By-Reference then do:
                    childObj:Add('mode':u, 'InputOutput':u).
                    childObj:Add('name':u, opParam:ABLName).
                    if opParam:IsArray then
                        childObj:AddNull('extent':u).
                    else
                        childObj:Add('extent':u, 0).
                    childObj:Add('xType':u, if num-entries(opParam:ABLType, ' ':u) eq 2 then entry(2, opParam:ABLType, ' ':u) else opParam:ABLType).
                    childObj:Add('type':u, 'REQUEST_BODY,RESPONSE_BODY':u).

                end.
                
                when OpenEdge.Core.IOModeEnum:Output or
                when OpenEdge.Core.IOModeEnum:Output-by-reference then do:
                    childObj:Add('mode':u, 'Output':u).
                    childObj:Add('name':u, opParam:ABLName).
                    if opParam:IsArray then
                        childObj:AddNull('extent':u).
                    else
                        childObj:Add('extent':u, 0).
                    childObj:Add('xType':u, if num-entries(opParam:ABLType, ' ':u) eq 2 then entry(2, opParam:ABLType, ' ':u) else opParam:ABLType).
                    childObj:Add('type':u, 'RESPONSE_BODY':u).
                end.

                otherwise
                    message substitute('Unknown IOMode &1 for &2':u, string(opParam:IOMode), opParam:ABLName).
            end case.

            assign operSchema = pMapOp:GetSchema(opParam:ABLName).
            if not valid-handle(operSchema) then
                assign operSchema = pService:GetSchema(opParam:ABLName).

            if valid-handle(operSchema) then do:
                case operSchema:type:
                    when 'dataset':u then
                        resource:GetJsonObject('schema':u):Set('properties':u, WriteDataset(operSchema)).
                    when 'buffer':u then
                        resource:GetJsonObject('schema':u):Set('properties':u, WriteTable(operSchema)).
                    when 'table':u then
                        resource:GetJsonObject('schema':u):Set('properties':u, WriteTable(operSchema:default-buffer-handle)).
                end case.
            end.

            paramArr:Add(childObj).             
        end. /* do while */

        operation:Add('params':u, paramArr).
        resource:GetJsonArray('operations':u):Add(operation).
    end method.

    method protected JsonObject WriteDataset ( input pDataset as handle ):
        define variable iX as integer no-undo.
        define variable iCnt as integer no-undo.
        define variable propsJson as JsonObject no-undo.
        define variable childData as JsonObject no-undo.
        define variable tableData as JsonObject no-undo.
        define variable bufferHdl as handle no-undo.
        

        if not valid-handle(pDataset) then
            return propsJson.

        assign propsJson   = new JsonObject()
               childData   = new JsonObject()
               iCnt        = pDataset:num-buffers
               .

        childData:Add('type':u, 'object':u).
        childData:Add('additionalProperties':u, false).
        propsJson:Add(pDataset:serialize-name, childData).

        assign tableData = new JsonObject().
        childData:Add('properties':u, tableData).

        do iX = 1 to iCnt:
            assign bufferHdl = pDataset:get-buffer-handle(iX).
            tableData:Add(bufferHdl:serialize-name, WriteTable(bufferHdl)).
        end.

        return propsJson.
    end method.

    method protected JsonObject WriteTable ( input pTable as handle ):
        define variable iX as integer no-undo.
        define variable iCnt as integer no-undo.
        define variable idx as integer no-undo.
        define variable tableJson as JsonObject no-undo.
        define variable fldJson as JsonObject no-undo.
        define variable itemsJson as JsonObject no-undo.
        define variable childObj as JsonObject no-undo.
        define variable bufferFld as handle no-undo.
        define variable fldFormat as character no-undo.
        define variable fldType as character no-undo.
        define variable propsJson as JsonObject no-undo.
        define variable uniqueFld as character no-undo.
        define variable idxInfo as character no-undo.
        define variable delim as character no-undo.

        if not valid-handle(pTable) then
            return tableJson.

        // determine required fields -> those that are in a unique index
        assign idx    = 1
               idxInfo = pTable:index-information(idx)
               .
        do while not idxInfo eq ?:
            if entry(2, idxInfo) eq '1':u then
            do:
                // index fields
                assign iCnt = num-entries(idxInfo).
                do iX = 5 to iCnt by 2:
                    if entry(iX, idxInfo) eq '':u then
                        next.
                    assign uniqueFld = uniqueFld + delim + entry(iX, idxInfo)
                           delim     = ',':u
                           .
                end.
            end.

            assign idx    = idx + 1
                   idxInfo = pTable:index-information(idx)
                   .
        end.

        assign tableJson = new JsonObject()
               itemsJson = new JsonObject()
               propsJson = new JsonObject()
               iCnt      = pTable:num-fields
               .
        tableJson:Add('type':u, 'array':u).
        tableJson:Add('items':u, itemsJson).
        itemsJson:Add('additionalProperties':u, false).
        itemsJson:Add('properties':u, propsJson).

        propsJson:Add('_id':u, new JsonObject()).
        propsJson:GetJsonObject('_id':u):Add('type':u, 'string':u).
        propsJson:Add('_errorString':u, new JsonObject()).
        propsJson:GetJsonObject('_errorString':u):Add('type':u, 'string':u).

        do iX = 1 to iCnt:
            assign bufferFld = pTable:buffer-field(iX).

            // not visible to the outside world
            if bufferFld:serialize-hidden then
                next.

            /* Create the new field object. */
            assign fldJson = new JsonObject().
            propsJson:Add(bufferFld:serialize-name, fldJson).

            assign fldType = FieldInfo(bufferFld:data-type,
                                       output fldFormat).

            if bufferFld:extent gt 0 then do:
                fldJson:Add('type':u, 'array':u).
                fldJson:Add('maxItems':u, bufferFld:extent).

                assign childObj = new JsonObject().
                fldJson:Add('items':u, childObj).
                childObj:Add('type':u, fldType).
                childObj:Add('ablType':u, caps(bufferFld:data-type)).
                fldJson:Add('title':u, bufferFld:label).

                WriteDefaultFieldValue(bufferFld, childObj).
            end. /* Extent */
            else do:
                fldJson:Add('type':u,  fldType).
                fldJson:Add('ablType':u, caps(bufferFld:data-type)).
                fldJson:Add('title':u, bufferFld:label).

                WriteDefaultFieldValue(bufferFld, fldJson).
            end. /* Normal */
            delete object bufferFld.
        end. /* num-fields */

        return tableJson.
    end method.

    method protected void WriteDefaultFieldValue ( input pField as handle,
                                                   input pJson as JsonObject ):
        if not valid-handle(pField)
           or not valid-object(pJson)
        then
            return.

        if pField:default-value eq ? then
            pJson:AddNull('default':u).
        else
        case pField:data-type:
            when 'date':u then
                // date-fullyear "-" date-month "-" date-mday
                pJson:Add('default':u, substitute('&1-&2-&3':u,
                                    string(year(pField:default-value), '9999':u),
                                    string(month(pField:default-value), '99':u),
                                    string(day(pField:default-value), '99':u))).

            when 'datetime':u or
            when 'datetime-tz':u then
                pJson:Add('default':u, iso-date(pField:default-value)).

            when 'integer':u or
            when 'int64':u then
                pJson:Add('default':u, int64(pField:default-value)).

            when 'decimal':u then
                pJson:Add('default':u, decimal(pField:default-value)).

            when 'logical':u then
                pJson:Add('default':u, logical(pField:default-value)).

            when 'blob':u or
            when 'raw':u then
                pJson:AddNull('default':u).

            otherwise
                pJson:Add('default':u, string(pField:default-value)).
        end case.
    end method.

    method protected character FieldInfo ( input  pAblType as character,
                                           output pFormat as character ):
        define variable fldType as character no-undo.

        case pAblType:
            when 'date':u then
                assign fldType = 'string':u
                       pFormat = 'date':u
                       .
            when 'datetime':u or
            when 'datetime-tz':u then
                assign fldType = 'string':u
                       pFormat = 'date-time':u
                       .
            when 'character':u or
            when 'clob':u or
            when 'longchar' then
                assign fldType = 'string':u
                       pFormat = '':u
                       .
            when 'integer':u then
                assign fldType = 'integer':u
                       pFormat = 'int32':u
                       .
            when 'int64':u then
                assign fldType = 'integer':u
                       pFormat = 'int64':u
                       .
            when 'decimal':u then
                assign fldType = 'number':u
                       pFormat = '':u
                       .
            when 'logical':u then
                assign fldType = 'boolean':u
                       pFormat = '':u
                       .
            when 'blob':u or
            when 'raw':u then
                assign fldType = 'string':u
                       pFormat = 'binary':u
                       .
            otherwise
                assign fldType = 'string':u
                       pFormat = '':u
                       .
        end case.

        return fldType.
    end method.

    method override protected void WriteSchema ( input pService as DataObjectService,
                                                 input pData as handle ):
        /* Does nothing here, will handle schema in-line within operation output. */
    end method.

end class.