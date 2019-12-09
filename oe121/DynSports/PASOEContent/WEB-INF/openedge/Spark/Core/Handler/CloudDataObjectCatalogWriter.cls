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

    define static public property CATALOG_VERSION as SemanticVersion no-undo
        get.
        private set.

    constructor static CloudDataObjectCatalogWriter ( ):
        assign CATALOG_VERSION = new SemanticVersion(1,5,0).
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

        catJson:Add('version':u, string(CATALOG_VERSION)). // REQUIRED. This string must be the semantic version number of the catalog.
        catJson:Add('lastModified':u, now).                // REQUIRED. Timestamp for when this catalog data was generated.
        catJson:Add('services':u, new JsonArray()).        // REQUIRED. The available services which have been defined.

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
                                                    input pData    as MappedOperation ):
        define variable serviceObj  as JsonObject no-undo.
        define variable resourceArr as JsonArray  no-undo.
        define variable resource    as JsonObject no-undo.
        define variable operation   as JsonObject no-undo.
        define variable cResource   as character  no-undo.
        define variable iCnt        as integer    no-undo.
        define variable iX          as integer    no-undo.

        if pData:name eq '':u then return. /* Can't proceed if there is no operation name. */

        assign serviceObj = this-object:GetServiceJson(pService:Name).
        if valid-object(serviceObj) and serviceObj:Has('resources':u) then
            assign resourceArr = serviceObj:GetJsonArray('resources':u).

        assign
            cResource = entry(1, left-trim(pData:ServiceURI, '~/':u), '~/':u)
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
            resource:Add('relations':u, new JsonArray()).
            resource:Add('operations':u, new JsonArray()).
            resource:Add('dataDefinitions':u, new JsonObject()).
            resourceArr:Add(resource).
        end.

        assign operation = new JsonObject().
        operation:Add('name':u, pData:name).
        operation:Add('path':u, substring(pData:ServiceURI, length(cResource) + 2)).
        operation:Add('useBeforeImage':u, false).
        if can-do("create,read,update,delete,submit", pData:name) then
            operation:Add('type':u, pData:name).
        else
            operation:Add('type':u, 'invoke':u).
        operation:Add('verb':u, lc(string(pData:Method))).
        operation:Add('params':u, new JsonArray()).
        resource:GetJsonArray('operations':u):Add(operation).

/*        do loop = 1 to cnt:                                                                                                                                                           */
/*            assign jsonData = operJson:GetJsonObject('responses':u):GetJsonObject(string(pData:StatusCode, '999':u)).                                                                 */
/*            case pData:ReturnValue:OutputElement[loop]:ElementType:                                                                                                                   */
/*                when ElementTypeEnum:Field then                                                                                                                                       */
/*                do:                                                                                                                                                                   */
/*                    if not jsonData:Has('content':u) then                                                                                                                             */
/*                    do:                                                                                                                                                               */
/*                        assign childObj    = new JsonObject()                                                                                                                         */
/*                               contentJson = new JsonObject()                                                                                                                         */
/*                               schemaJson  = new JsonObject()                                                                                                                         */
/*                               .                                                                                                                                                      */
/*                        jsonData:Add('content':u,   childObj).                                                                                                                        */
/*                            childObj:Add(pData:ContentType, contentJson).                                                                                                             */
/*                                contentJson:Add('schema':u, schemaJson).                                                                                                              */
/*                                    schemaJson:Add('type':u, 'object':u).                                                                                                             */
/*                                    schemaJson:Add('description':u, 'FIELD mapping').                                                                                                 */
/*                    end.                                                                                                                                                              */
/*                end.                                                                                                                                                                  */
/*                                                                                                                                                                                      */
/*                when ElementTypeEnum:Body then                                                                                                                                        */
/*                do:                                                                                                                                                                   */
/*                    assign childObj    = new JsonObject()                                                                                                                             */
/*                           contentJson = new JsonObject()                                                                                                                             */
/*                           schemaJson  = new JsonObject()                                                                                                                             */
/*                           .                                                                                                                                                          */
/*                    jsonData:Add('content':u,   childObj).                                                                                                                            */
/*                        childObj:Add(pData:ContentType, contentJson).                                                                                                                 */
/*                            contentJson:Add('schema':u, schemaJson).                                                                                                                  */
/*                    // for per-operation schemas, use inline; for service schemas, use a reference                                                                                    */
/*                    assign operSchema = pData:GetSchema(pData:ReturnValue:ABLName).                                                                                                   */
/*                    if valid-handle(operSchema) then                                                                                                                                  */
/*                    do:                                                                                                                                                               */
/*                        assign schemaChild = new JsonObject().                                                                                                                        */
/*                                                                                                                                                                                      */
/*                        schemaJson:Add('type':u, 'object':u).                                                                                                                         */
/*                        schemaJson:Add('additionalProperties':u, false).                                                                                                              */
/*                        schemaJson:Add('properties', schemaChild).                                                                                                                    */
/*                                                                                                                                                                                      */
/*                        case operSchema:type:                                                                                                                                         */
/*                            when 'dataset':u then                                                                                                                                     */
/*                                schemaChild:Add(operSchema:serialize-name, WriteDataset(operSchema)).                                                                                 */
/*                            when 'buffer':u then                                                                                                                                      */
/*                                schemaChild:Add(operSchema:serialize-name, WriteTable(operSchema)).                                                                                   */
/*                            when 'table':u then                                                                                                                                       */
/*                                schemaChild:Add(operSchema:serialize-name, WriteTable(operSchema:default-buffer-handle)).                                                             */
/*                        end case.                                                                                                                                                     */
/*                    end.                                                                                                                                                              */
/*                    else                                                                                                                                                              */
/*                        assign operSchema = pService:GetSchema(pData:ReturnValue:ABLName).                                                                                            */
/*                                                                                                                                                                                      */
/*                    if valid-handle(operSchema) then                                                                                                                                  */
/*                        schemaJson:Add('$ref':u, '#/components/schemas/':u + operSchema:serialize-name).                                                                              */
/*                    else                                                                                                                                                              */
/*                        schemaJson:Add('type':u, 'object':u).                                                                                                                         */
/*                end.                                                                                                                                                                  */
/*                otherwise                                                                                                                                                             */
/*                    next.                                                                                                                                                             */
/*            end case.                                                                                                                                                                 */
/*        end.        //output                                                                                                                                                          */
/*                                                                                                                                                                                      */
/*        //parameters                                                                                                                                                                  */
/*        assign iter      = pData:Parameters:Iterator()                                                                                                                                */
/*               paramJson = operJson:GetJsonArray('parameters':u)                                                                                                                      */
/*               .                                                                                                                                                                      */
/*        do while iter:HasNext():                                                                                                                                                      */
/*            assign opParam  = cast(iter:Next(), OperationParameter).                                                                                                                  */
/*                                                                                                                                                                                      */
/*            // we only care about inputs here                                                                                                                                         */
/*            assign cnt = extent(opParam:InputElement).                                                                                                                                */
/*            do loop = 1 to cnt:                                                                                                                                                       */
/*                // REQUIRED. The location of the parameter. Possible values are "query", "header", "path" or "cookie".                                                                */
/*                case opParam:InputElement[loop]:ElementType:                                                                                                                          */
/*                    when ElementTypeEnum:Query  or                                                                                                                                    */
/*                    when ElementTypeEnum:Header or                                                                                                                                    */
/*                    when ElementTypeEnum:Cookie or                                                                                                                                    */
/*                    when ElementTypeEnum:Path then                                                                                                                                    */
/*                    do:                                                                                                                                                               */
/*                        assign childObj   = new JsonObject()                                                                                                                          */
/*                               schemaJson = new JsonObject()                                                                                                                          */
/*                               fldType    = FieldInfo(opParam:ABLType, output fldFormat)                                                                                              */
/*                               .                                                                                                                                                      */
/*                        paramJson:Add(childObj).                                                                                                                                      */
/*                            childObj:Add('in':u,        lc(string(opParam:InputElement[loop]:ElementType))).                                                                          */
/*                            childObj:Add('name':u,      opParam:InputElement[loop]:ElementName).                                                                                      */
/*                            childObj:Add('required':u,  (opParam:InputElement[loop]:ElementType eq ElementTypeEnum:Path)).                                                            */
/*                            childObj:Add('schema':u, schemaJson).                                                                                                                     */
/*                                schemaJson:Add('type':u,   fldType).                                                                                                                  */
/*                                schemaJson:Add('format':u, fldFormat).                                                                                                                */
/*                                schemaJson:Add('description':u, caps(string(opParam:InputElement[loop]:ElementType)) + ' mapping').                                                   */
/*                    end.                                                                                                                                                              */
/*                                                                                                                                                                                      */
/*                    when ElementTypeEnum:Field then                                                                                                                                   */
/*                    do:                                                                                                                                                               */
/*                        if not operJson:Has('requestBody':u) then                                                                                                                     */
/*                        do:                                                                                                                                                           */
/*                            assign childObj    = new JsonObject()                                                                                                                     */
/*                                   jsonData    = new JsonObject()                                                                                                                     */
/*                                   contentJson = new JsonObject()                                                                                                                     */
/*                                   schemaJson  = new JsonObject()                                                                                                                     */
/*                                   .                                                                                                                                                  */
/*                            operJson:Add('requestBody':u, childObj).                                                                                                                  */
/*                                childObj:Add('description':u, opParam:ABLType).                                                                                                       */
/*                                childObj:Add('content':u,   jsonData).                                                                                                                */
/*                                    jsonData:Add(pData:ContentType, contentJson).                                                                                                     */
/*                                        contentJson:Add('schema':u, schemaJson).                                                                                                      */
/*                                            schemaJson:Add('type':u, 'object':u).                                                                                                     */
/*                                            schemaJson:Add('description':u, 'FIELD mapping').                                                                                         */
/*                        end.                                                                                                                                                          */
/*                    end.                                                                                                                                                              */
/*                                                                                                                                                                                      */
/*                    when ElementTypeEnum:Body then                                                                                                                                    */
/*                    do:                                                                                                                                                               */
/*                        assign childObj    = new JsonObject()                                                                                                                         */
/*                               jsonData    = new JsonObject()                                                                                                                         */
/*                               contentJson = new JsonObject()                                                                                                                         */
/*                               schemaJson  = new JsonObject()                                                                                                                         */
/*                               .                                                                                                                                                      */
/*                        operJson:Add('requestBody':u, childObj).                                                                                                                      */
/*                            childObj:Add('description':u, opParam:ABLType).                                                                                                           */
/*                            childObj:Add('content':u,   jsonData).                                                                                                                    */
/*                                jsonData:Add(pData:ContentType, contentJson).                                                                                                         */
/*                                    contentJson:Add('schema':u, schemaJson).                                                                                                          */
/*                        // for per-operation schemas, use inline; for service schemas, use a reference                                                                                */
/*                        assign operSchema  = pData:GetSchema(opParam:ABLName).                                                                                                        */
/*                        if valid-handle(operSchema) then                                                                                                                              */
/*                        do:                                                                                                                                                           */
/*                            assign schemaChild = new JsonObject().                                                                                                                    */
/*                            schemaJson:Add('type':u, 'object':u).                                                                                                                     */
/*                            schemaJson:Add('description':u, 'BODY mapping').                                                                                                          */
/*                            schemaJson:Add('additionalProperties':u, false).                                                                                                          */
/*                            schemaJson:Add('properties', schemaChild).                                                                                                                */
/*                            /*                                                                                                                                                        */
/*                                "type": "object",                                                                                                                                     */
/*                                "additionalProperties": false,                                                                                                                        */
/*                                "properties": {"dsEmployee": {                                                                                                                        */
/*                            */                                                                                                                                                        */
/*                            case operSchema:type:                                                                                                                                     */
/*                                when 'dataset':u then                                                                                                                                 */
/*                                    schemaChild:Add(operSchema:serialize-name, WriteDataset(operSchema)).                                                                             */
/*                                when 'buffer':u then                                                                                                                                  */
/*                                    schemaChild:Add(operSchema:serialize-name, WriteTable(operSchema)).                                                                               */
/*                                when 'table':u then                                                                                                                                   */
/*                                    schemaChild:Add(operSchema:serialize-name, WriteTable(operSchema:default-buffer-handle)).                                                         */
/*                            end case.                                                                                                                                                 */
/*                        end.                                                                                                                                                          */
/*                        else                                                                                                                                                          */
/*                            assign operSchema = pService:GetSchema(opParam:ABLName).                                                                                                  */
/*                                                                                                                                                                                      */
/*                        if valid-handle(operSchema) then                                                                                                                              */
/*                        do:                                                                                                                                                           */
/*                            schemaJson:Add('$ref':u, '#/components/schemas/':u + operSchema:serialize-name).                                                                          */
/*                        end.                                                                                                                                                          */
/*                        else                                                                                                                                                          */
/*                            schemaJson:Add('type':u, 'object':u).                                                                                                                     */
/*                    end.                                                                                                                                                              */
/*                                                                                                                                                                                      */
/*                    otherwise                                                                                                                                                         */
/*                        next.                                                                                                                                                         */
/*                end case.                                                                                                                                                             */
/*            end.    // input loop                                                                                                                                                     */
/*                                                                                                                                                                                      */
/*            // now outputs                                                                                                                                                            */
/*            assign cnt = extent(opParam:OutputElement).                                                                                                                               */
/*            do loop = 1 to cnt:                                                                                                                                                       */
/*                assign jsonData = operJson:GetJsonObject('responses':u):GetJsonObject(string(pData:StatusCode, '999':u)).                                                             */
/*                case opParam:OutputElement[loop]:ElementType:                                                                                                                         */
/*                    when ElementTypeEnum:Field then                                                                                                                                   */
/*                    do:                                                                                                                                                               */
/*                        if not jsonData:Has('content':u) then                                                                                                                         */
/*                        do:                                                                                                                                                           */
/*                            assign childObj    = new JsonObject()                                                                                                                     */
/*                                   contentJson = new JsonObject()                                                                                                                     */
/*                                   schemaJson  = new JsonObject()                                                                                                                     */
/*                                   .                                                                                                                                                  */
/*                            jsonData:Add('content':u,   childObj).                                                                                                                    */
/*                                childObj:Add(pData:ContentType, contentJson).                                                                                                         */
/*                                    contentJson:Add('schema':u, schemaJson).                                                                                                          */
/*                                        schemaJson:Add('type':u, 'object':u).                                                                                                         */
/*                                        schemaJson:Add('description':u, 'FIELD mapping').                                                                                             */
/*                        end.                                                                                                                                                          */
/*                    end.                                                                                                                                                              */
/*                                                                                                                                                                                      */
/*                    when ElementTypeEnum:Body then                                                                                                                                    */
/*                    do:                                                                                                                                                               */
/*                        assign childObj    = new JsonObject()                                                                                                                         */
/*                               contentJson = new JsonObject()                                                                                                                         */
/*                               schemaJson  = new JsonObject()                                                                                                                         */
/*                               .                                                                                                                                                      */
/*                        if not jsonData:Has('content':U) then                                                                                                                         */
/*                        do:                                                                                                                                                           */
/*                            jsonData:Add('content':u,   childObj).                                                                                                                    */
/*                                    childObj:Add(pData:ContentType, contentJson).                                                                                                     */
/*                                        contentJson:Add('schema':u, schemaJson).                                                                                                      */
/*                        end.                                                                                                                                                          */
/*                        else                                                                                                                                                          */
/*                            assign schemaJson = jsonData:GetJsonObject('content':u)                                                                                                   */
/*                                                            :GetJsonObject(pData:ContentType)                                                                                         */
/*                                                                :GetJsonObject('schema':u).                                                                                           */
/*                                                                                                                                                                                      */
/*                        // for per-operation schemas, use inline; for service schemas, use a reference                                                                                */
/*                        assign operSchema = pData:GetSchema(opParam:ABLName).                                                                                                         */
/*                        if valid-handle(operSchema) then                                                                                                                              */
/*                        do:                                                                                                                                                           */
/*                            assign schemaChild = new JsonObject().                                                                                                                    */
/*                            schemaJson:Add('type':u, 'object':u).                                                                                                                     */
/*                            schemaJson:Add('description':u, 'BODY mapping').                                                                                                          */
/*                            schemaJson:Add('additionalProperties':u, false).                                                                                                          */
/*                            schemaJson:Add('properties', schemaChild).                                                                                                                */
/*                            /*                                                                                                                                                        */
/*                                "type": "object",                                                                                                                                     */
/*                                "additionalProperties": false,                                                                                                                        */
/*                                "properties": {"dsEmployee": {                                                                                                                        */
/*                            */                                                                                                                                                        */
/*                            case operSchema:type:                                                                                                                                     */
/*                                when 'dataset':u then                                                                                                                                 */
/*                                    schemaChild:Add(operSchema:serialize-name, WriteDataset(operSchema)).                                                                             */
/*                                when 'buffer':u then                                                                                                                                  */
/*                                    schemaChild:Add(operSchema:serialize-name, WriteTable(operSchema)).                                                                               */
/*                                when 'table':u then                                                                                                                                   */
/*                                    schemaChild:Add(operSchema:serialize-name, WriteTable(operSchema:default-buffer-handle)).                                                         */
/*                            end case.                                                                                                                                                 */
/*                        end.                                                                                                                                                          */
/*                        else                                                                                                                                                          */
/*                            assign operSchema = pService:GetSchema(opParam:ABLName).                                                                                                  */
/*                        if valid-handle(operSchema) then                                                                                                                              */
/*                        do:                                                                                                                                                           */
/*                            schemaJson:Add('$ref':u, '#/components/schemas/':u + operSchema:serialize-name).                                                                          */
/*                        end.                                                                                                                                                          */
/*                        else                                                                                                                                                          */
/*                            schemaJson:Add('type':u, 'object':u).                                                                                                                     */
/*                    end.                                                                                                                                                              */
/*                                                                                                                                                                                      */
/*                    otherwise                                                                                                                                                         */
/*                        next.                                                                                                                                                         */
/*                end case.                                                                                                                                                             */
/*            end.        //output                                                                                                                                                      */
/*        end.                                                                                                                                                                          */
    end method.

    method protected JsonObject WriteDataset ( input pDataset as handle ):
        define variable loop as integer no-undo.
        define variable cnt as integer no-undo.
        define variable childData as JsonObject no-undo.
        define variable datasetJson as JsonObject no-undo.
        define variable bufferHdl as handle no-undo.
        define variable propsJson as JsonObject no-undo.

        if not valid-handle(pDataset) then
            return datasetJson.

        assign datasetJson = new JsonObject()
               propsJson   = new JsonObject()
               childData   = new JsonObject()
               cnt         = pDataset:num-buffers
               .
        datasetJson:Add('type':u, 'object':u).
        datasetJson:Add('additionalProperties':u, false).
        datasetJson:Add('properties':u, propsJson).
            propsJson:Add(pDataset:serialize-name, childData).
                childData:Add('type':u, 'object':u).
                childData:Add('additionalProperties':u, false).

        assign propsJson = new JsonObject().
                childData:Add('properties':u, propsJson).

        do loop = 1 to cnt:
            assign bufferHdl = pDataset:get-buffer-handle(loop).
            propsJson:Add(bufferHdl:serialize-name, WriteTable(bufferHdl)).
        end.

        return datasetJson.
    end method.

    method protected JsonObject WriteTable ( input pTable as handle ):
        define variable loop as integer no-undo.
        define variable cnt as integer no-undo.
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
                assign cnt = num-entries(idxInfo).
                do loop = 5 to cnt by 2:
                    if entry(loop, idxInfo) eq '':u then
                        next.
                    assign uniqueFld = uniqueFld + delim + entry(loop, idxInfo)
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
               cnt       = pTable:num-fields
               .
        tableJson:Add('type':u, 'array':u).
        tableJson:Add('items':u, itemsJson).
            itemsJson:Add('additionalProperties':u, false).
            itemsJson:Add('properties':u, propsJson).

        do loop = 1 to cnt:
            assign bufferFld = pTable:buffer-field(loop).

            // not visible to the outside world
            if bufferFld:serialize-hidden then
                next.

            /* Create the new field object. */
            assign fldJson= new JsonObject().
            propsJson:Add(bufferFld:serialize-name, fldJson).

            assign fldType = FieldInfo(bufferFld:data-type,
                                       output fldFormat).

            if bufferFld:extent gt 0 then
            do:
                fldJson:Add('type':u, 'array':u).
                fldJson:Add('title':u, bufferFld:label).
                fldJson:Add('maxItems':u, bufferFld:extent).
                assign childObj = new JsonObject().
                fldJson:Add('items':u, childObj).
                    childObj:Add('type':u, fldType).
                    childObj:Add('nullable':u, true).
                    if lookup(bufferFld:name, uniqueFld) gt 0 then
                        childObj:Add('required':u, true).

                    if not fldFormat eq '':u then
                        childObj:Add('format':u, fldFormat ).

                    WriteDefaultFieldValue(bufferFld, childObj).
            end. /* Extent */
            else
            do:
                fldJson:Add('title':u, bufferFld:label).
                fldJson:Add('type':u,  fldType).
                fldJson:Add('nullable':u, true).
                if lookup(bufferFld:name, uniqueFld) gt 0 then
                    fldJson:Add('required':u, true).
                if not fldFormat eq '':u then
                    fldJson:Add('format':u, fldFormat ).

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
                //date-fullyear "-" date-month "-" date-mday
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