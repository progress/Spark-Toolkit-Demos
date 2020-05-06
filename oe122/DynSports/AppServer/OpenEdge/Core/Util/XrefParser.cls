 /************************************************
Copyright (c) 2020 by Progress Software Corporation. All rights reserved.
*************************************************/
/*------------------------------------------------------------------------
    File        : XrefParser
    Purpose     : Utility to read an XML XREF file and return the annotations for a given ABL program
                  in JSON
    Author(s)   : pjudge
    Created     : 2018-11-08
    Notes       : 
  ----------------------------------------------------------------------*/
block-level on error undo, throw.

using OpenEdge.Core.Assert.
using OpenEdge.Core.Assertion.AssertFile.
using OpenEdge.Core.Collections.IIterator.
using OpenEdge.Core.Collections.IStringStringMap.
using OpenEdge.Core.ISupportInitialize.
using OpenEdge.Core.StringConstant.
using Progress.Json.ObjectModel.JsonArray.
using Progress.Json.ObjectModel.JsonDataType.
using Progress.Json.ObjectModel.JsonObject.

class OpenEdge.Core.Util.XrefParser implements ISupportInitialize:
    
    {OpenEdge/Core/Util/dsxref.i ACCESS-LEVEL=PRIVATE}
    
    /* Default constructor */
    constructor public XrefParser():
    end constructor.
    
    /* Constructor.
       
       @param character The name of a XML-XREF file to read */
    constructor public XrefParser(input pFilename as character):
        this-object().
        
        // if the file exists, load from it. ParseXref will throw an error if the file doesn't exist 
        // but we don't want to be doing that from the constructor
        assign file-info:file-name = pFilename.
        if not file-info:full-pathname eq ?
           and index(file-info:file-type, 'F':u) gt 0
        then
            ParseXref(pFilename).
    end constructor.
     
    method public void Initialize():
        dataset dsXref:empty-dataset().
    end method.

    method public void Destroy():
        dataset dsXref:empty-dataset().
    end method.
    
    /* Reads an XML REF file into the local storage. Multiple files can be read.
       
       @param character The name of the XML-XREF file */
    method public void ParseXref(input pFilename as character):
        AssertFile:FileExists(pFilename).
        assign file-info:file-name = pFilename.
        
        dataset dsXref:read-xml('file':u, file-info:full-pathname, ?,?,?).
    end method.
    
    /* Method to find Source record for a given program. The input buffer is positioned
       to a record, if found.
       
       @param character The program name
       @param buffer Source The buffer in which to find the record */
    method private void FindSourceRecord (input pAblProgram as character,
                                          buffer pSource for Source):
        release pSource.
        
        // look for slash-delimited files
        assign pAblProgram = replace(pAblProgram, StringConstant:BACKSLASH, '/':u).
        if can-find(first pSource where pSource.File-name eq pAblProgram) then
             find first pSource where pSource.File-name eq pAblProgram.
        else
        // look for backslash-delimited files
        do:
            assign pAblProgram = replace(pAblProgram, '/':u, StringConstant:BACKSLASH). 
            if can-find(first pSource where pSource.File-name eq pAblProgram) then
                 find first pSource where pSource.File-name eq pAblProgram.
        end.
    end method.
    
    /* Returns the annotations in JSON form for a given file.
       
       The JSON returned is either contains only a null "program" property  
            { "program": null }
       or has the structure
       {
         // these are annotations that belong to the class/procedure
         "program": {
            "annotation-name-1": null,
            "annotation-name-2": {
                "key-1": "value-1",
                "key-n": "value-n"
                }
            }
         
         // these have no parameters or cannot be overloaded. the name never has a paren
         "destructor"
         "procedure"
         "function"
         "property"
         "event": {
             "name": {
                 "annotation-name-1": null,
                 "annotation-name-2": {
                     "key-1": "value-1",
                     "key-n": "value-n"
                 },
                 "annotation-name-2": {
                    "key-1": "value-1",
                    // if there are multiple annotation keys, store their values in a string array
                    "key-2": ["value-2-1", "value-2-n"]
                 }
             }
          }
         
         // these are members that can be overloaded. the name always has parens.
         "constructor"
         "method": {
             "name(<iomode-1> <param-type-1>, <iomode-n> <param-type-n>)": 
             "name()": {
                 "annotation-name-1": null,
                  // if there are more than one annotation with the same name, add an array of value obejcts
                 "annotation-name-2": [ 
                    {
                     "key-1": "value-1",
                     "key-n": "value-n"
                    },
                    {"key-1": "value-1"}
                 ]
             }
         }
       }
       
       @param character The name of the ABL file (class/procecure/etc) for which to extract annotations
       @param IStringStringMap A map of an annotation to a user-defined group. The group is created under a "user" property. 
                               Unknown values are allowed.
       @return JsonObject A JSON object containing the annotations. A valid object is always returned.   */
    method public JsonObject GetAnnotations(input pAblProgram as character,
                                            input pUserMap as IStringStringMap):
        define variable loop as integer no-undo.
        define variable cnt as integer no-undo.
        define variable pos as integer no-undo.
        define variable propNames as longchar extent no-undo.
        define variable endPos as integer no-undo.
        define variable annoVals as character no-undo.
        define variable annoName as character no-undo.
        define variable annoKvp as character no-undo.
        define variable annoKey as character no-undo.
        define variable annoValue as character no-undo.
        define variable delim as character no-undo.
        define variable propGroup as character no-undo.
        define variable groupData as JsonObject no-undo.    // a set of annotations for a method/etc
        define variable annotations as JsonObject no-undo.  // the complete set of annotations for a program
        define variable valueData as JsonObject no-undo.    // a set of props with data for a single anno
        define variable jsonData as JsonObject no-undo.
        define variable groupSet as JsonArray no-undo.
        define variable valueSet as JsonArray no-undo.
        define variable iter as IIterator no-undo.
        
        define buffer lbSource for Source.
        define buffer lbReference for Reference.
        define buffer lbParam for Parameter-ref.
        
        Assert:NotNullOrEmpty(pAblProgram, 'ABL program').
        
        assign groupData   = new JsonObject()
               annotations = new JsonObject()
               pos         = r-index(pAblProgram, '.':u)
               .
        annotations:AddNull('program':u).
        annotations:Add('data':u, new JsonObject()).
        
        if not valid-object(pUserMap) then
            annotations:AddNull('user':u).
        else
        do:
            assign groupData = new JsonObject()
                   iter      = pUserMap:Values:Iterator()
                   .
            annotations:Add('user':u, groupData).
            
            do while iter:HasNext():
                assign propGroup = iter:Next():ToString().
                
                if  not propGroup eq ?
                and not propGroup eq '':u   
                and not groupData:Has(propGroup) 
                then
                    groupData:Add(propGroup, new JsonObject()).
            end.
            // reset for others 
            assign groupData = ?.
        end.
        
        FindSourceRecord(pAblProgram, buffer lbSource).
        if not available lbSource then
            return annotations.
        
        if substring(pAblProgram, pos + 1) eq 'cls':u then
        do:
            annotations:Add('method':u,      new JsonObject()).
            annotations:Add('constructor':u, new JsonObject()).
            annotations:Add('destructor':u,  new JsonObject()).
            annotations:Add('property':u,    new JsonObject()).
            annotations:Add('event':u,       new JsonObject()).
        end.
        else
        do:
            annotations:Add('procedure':u, new JsonObject()).
            annotations:Add('function':u,  new JsonObject()).
        end.
        
        for each lbReference where
                 lbReference.Source-guid eq lbSource.Source-guid 
                 by lbReference.ref-seq:
            case lbReference.reference-type:
                when 'annotation':u then
                do:
                    // The annotation name is either annotation.name or annotation.name(key=value)  
                    assign pos      = index(lbReference.Object-identifier, '(':u)
                           annoName = trim(substring(lbReference.Object-identifier, 1, pos - 1) )
                           .
                    // no annotation value, just a name
                    if pos eq 0 then
                        assign annoName  = trim(lbReference.Object-identifier)
                               valueData = ?
                               .
                    else
                    do:
                        assign valueData = new JsonObject()
                               // don't TRIM; we only want to remove the last single ) paren
                               annoVals  = substring(lbReference.Object-identifier, pos + 1)
                               annoVals  = substring(annoVals, 1, length(annoVals) - 1)
                               cnt       = num-entries(annoVals)
                               .
                        do loop = 1 to cnt:
                            assign annoKvp   = entry(loop, annoVals)
                                   pos       = index(annoKvp, '=':u)
                                   annoKey   = trim(entry(1, annoKvp, '=':u))
                                   annoValue = trim(substring(annoKvp, pos + 1))
                                   .
                            if valueData:Has(annoKey) then
                            case valueData:GetType(annoKey):
                                when JsonDataType:NULL then
                                do:
                                    assign valueSet = new JsonArray().
                                    valueSet:AddNull().
                                    if pos eq 0 then
                                        valueSet:AddNull().
                                    else
                                        valueSet:Add(annoValue).
                                    
                                    valueData:Set(annoKey, valueSet).
                                end.
                                
                                when JsonDataType:STRING then
                                do:
                                    assign valueSet = new JsonArray().
                                    valueSet:Add(valueData:GetCharacter(annoKey)).
                                    if pos eq 0 then
                                        valueSet:AddNull().
                                    else
                                        valueSet:Add(annoValue).
                                    valueData:Set(annoKey, valueSet).
                                end.
                                
                                when JsonDataType:ARRAY then
                                do:
                                    assign valueSet = valueData:GetJsonArray(annoKey).
                                    if pos eq 0 then
                                        valueSet:AddNull().
                                    else
                                        valueSet:Add(annoValue).
                                end.
                            end.
                            else
                            if pos eq 0 then
                                valueData:AddNull(annoKey).
                            else
                                valueData:Add(annoKey, annoValue).
                        end.
                    end.
                    
                    if  valid-object(pUserMap)
                    and pUserMap:ContainsKey(annoName)
                    then
                    do:
                        assign propGroup = string(pUserMap:Get(annoName)).
                        if  not propGroup eq ?
                        and not propGroup eq '':u
                        then
                            assign jsonData  = groupData
                                   groupData = annotations:GetJsonObject('user':u)
                                                          :GetJsonObject(propGroup)
                                   .
                    end.
                    
                    // if there's more that one annotation with the same name, we add an object per annotation
                    // anno: {a:b, c:d}
                    // anno: null
                    // anno: [{a:b, c:d}, {f:g}, null]
                    if groupData:Has(annoName) then
                    case groupData:GetType(annoName):
                        when JsonDataType:ARRAY then
                            groupData:GetJsonArray(annoName)
                                     :Add(valueData).
                        
                        when JsonDataType:OBJECT or
                        when JsonDataType:NULL then
                        do:
                            assign groupSet = new JsonArray().
                            groupSet:Add(groupData:GetJsonObject(annoName)).
                            groupSet:Add(valueData).
                            groupData:Set(annoName, groupSet).
                        end.
                    end case.
                    else
                        groupData:Add(annoName, valueData).
                    
                    // reset groupData
                    if valid-object(jsonData) then
                        assign groupData = jsonData
                               jsonData  = ?
                               .
                end.
                
                // We don't need a name for these , since all of these are for a single 
                // program/compile unit 
                when 'compile':u or
                when 'class':u then
                do:
                    annotations:Set('program':u, groupData).
                    assign groupData = new JsonObject().
                end.
                
                // these have no parameters
                when 'destructor':u or
                when 'procedure':u or
                when 'private-procedure':u or
                when 'function':u or
                when 'private-function':u or
                when 'property':u or
                when 'event':u then
                do:
                    assign propGroup = lc(lbReference.reference-type)
                           propGroup = replace(propGroup, 'private-':u, '':u)
                           .
                    annotations:GetJsonObject(propGroup)
                               :Add(lbReference.object-identifier, groupData).
                    assign groupData = new JsonObject().
                end.
                
                // temp-tables and datasets, as long as they're PROTECTED or more open
                // otherwise they go who-knows-where
                when 'data-member':u then
                do:
                    annotations:GetJsonObject('data':u)
                               :Add(lbReference.object-identifier, groupData).
                    assign groupData = new JsonObject().
                end.
                
                // members that support overloading
                when 'constructor':u or
                when 'method':u then
                do:
                    assign annoName = '':u
                           delim    = '':u
                           .
                    for each lbParam where
                             lbParam.Source-guid eq lbReference.Source-guid and
                             lbParam.Ref-seq eq lbReference.Ref-seq
                             by lbParam.Order:
                        assign annoName = substitute('&1&4&2 &3':u,
                                            annoName,
                                            lbParam.Parameter-mode,
                                            lbParam.Parameter-type,
                                            delim)
                              delim    = ',':u
                              .
                    end.
                    
                    annotations:GetJsonObject(lc(lbReference.reference-type))
                               :Add(substitute('&1(&2)':u, lbReference.object-identifier, annoName),
                                    groupData).
                    
                    assign groupData = new JsonObject().
                end.
            end case.
        end.
        
        // If there are annotations that are written after any public things, add to the compile unit
        if valid-object(groupData) then
        do:
            assign extent(propNames) = ?
                   propNames         = groupData:GetNames()
                   cnt               = extent(propNames)
                   valueData         = annotations:GetJsonObject('program':u) 
                   .
            do loop = 1 to cnt:
                valueData:Add(string(propNames[loop]),
                              groupData:GetJsonObject(string(propNames[loop]))).
            end. 
        end.
        
        return annotations.
    end method.
end class.
