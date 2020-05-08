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
         
         // these are annotations that match the input user map 
         "user" {
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
using OpenEdge.Core.Json.JsonConverter.
using OpenEdge.Core.String.
using OpenEdge.Core.Json.JsonPropertyHelper.

class OpenEdge.Core.Util.XrefParser implements ISupportInitialize:
    
    {OpenEdge/Core/Util/dsxref.i ACCESS-LEVEL=PRIVATE }
    
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
    
    /* Initializer/Startup */
    method public void Initialize():
        dataset dsXref:empty-dataset().
    end method.
    
    /* Destroy/Shutdown/Anti-Initializer */
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
       
       @param character The name of the ABL file (class/procecure/etc) for which to extract annotations
       @param IStringStringMap A map of an annotation to a user-defined group. The group is created under a "user" property. 
                               Unknown values are allowed.
       @return JsonObject A JSON object containing the annotations. A valid object is always returned. */
    method public JsonObject GetAnnotations(input pAblProgram as character,
                                            input pUserMap as IStringStringMap):
        define variable annoData as JsonObject no-undo.
        define variable progData as JsonObject no-undo.
        define buffer lbSource for Source.
        define buffer lbRef for Reference.
        
        assign annoData = new JsonObject().
        if pAblProgram eq ?
        or pAblProgram eq '':u
        then
        do:
            assign progData = new JsonObject().
            progData:AddNull('program':u).
            annoData:Add('<empty>', progData).
            
            return annoData.
        end.
        
        FindSourceRecord(pAblProgram, buffer lbSource).
        
        assign progData = ExtractAnnotations(buffer lbSource, pUserMap).
        find  lbRef
        where lbRef.Source-guid eq lbSource.Source-guid
          and lbRef.Reference-type eq 'CLASS':u
        no-error.
        
        if available lbRef then
            annoData:Add(lbRef.Object-identifier, progData). 
        else
            annoData:Add(pAblProgram, progData). 
        
        return annoData.
    end method.
    
    /* Returns the annotations in JSON form for a given file.
       @param IStringStringMap A map of an annotation to a user-defined group. The group is created under a "user" property. 
                               Unknown values are allowed.
       @return JsonObject A JSON object containing the annotations. A valid object is always returned.   */
    method public JsonObject GetAnnotations(input pUserMap as IStringStringMap):
        define variable annoData as JsonObject no-undo.
        define variable progData as JsonObject no-undo.
        define variable refName as character no-undo.
        define variable refCnt as integer no-undo.
        define buffer lbSource for Source.
        define buffer lbRef for Reference.
        
        assign annoData = new JsonObject().
        for each lbSource
           where lbSource.File-num eq 1
              by lbSource.File-name:
            find  lbRef
            where lbRef.Source-guid eq lbSource.Source-guid
              and lbRef.Reference-type eq 'CLASS':u
            no-error.
            
            assign progData = ExtractAnnotations(buffer lbSource, pUserMap).
            if available lbRef then
                assign refName = lbRef.Object-identifier. 
            else
                assign refName = replace(lbSource.File-name, StringConstant:BACKSLASH, '/':u)
                       refName = entry(num-entries(refName, '/':u), refName, '/':u) 
                       .
            // in case we have dups
            if annoData:Has(refName) then
            do:
                assign refCnt = 1.
                do while annoData:Has(substitute('&1(&2)', refName, refCnt)):
                    assign refCnt = refCnt + 1.
                end.
                assign refName = substitute('&1(&2)', refName, refCnt).
            end.
            
            annoData:Add(refName, progData). 
        end.
        
        return annoData.
    end method.
    
    /* Extracts annotations for a single program 
       
       @param buffer Source The current program whose annotations to extract
       @param IStringStringMap A map of an annotation to a user-defined group. The group is created under a "user" property. 
                               Unknown values are allowed.
       @return JsonObject A JSON object containing the annotations. A valid object is always returned.   */
    method protected JsonObject ExtractAnnotations(buffer pSource for Source,
                                                   input  pUserMap as IStringStringMap):
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
        
        define buffer lbSrc for Source. 
        
        assign annotations = new JsonObject().
        annotations:AddNull('fileName':u).
        
        if not available pSource then
            return annotations.
        
        assign groupData = new JsonObject()
               pos       = r-index(pSource.File-name, '.':u)
               .
        
        annotations:Set('fileName':u, pSource.File-name).
        annotations:AddNull('program':u).
        annotations:AddNull('data':u).
        
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
                    groupData:AddNull(propGroup).
            end.
        end.
        
        if substring(pSource.File-name, pos + 1) eq 'cls':u then
        do:
            annotations:AddNull('method':u).
            annotations:AddNull('constructor':u).
            annotations:AddNull('destructor':u).
            annotations:AddNull('property':u).
            annotations:AddNull('event':u).
        end.
        else
        do:
            annotations:AddNull('procedure':u).
            annotations:AddNull('function':u).
        end.
        
        // add the file itself 
        AddReferences(buffer pSource, pUserMap, annotations).
       
        for each lbSrc 
           where lbSrc.Source-guid eq pSource.Source-guid
             and lbSrc.File-Num    ge 2    // read any includes 
              by lbSrc.File-Num:
            AddReferences(buffer lbSrc, pUserMap, annotations).
        end.
        
        return annotations.
    end method.
    
    /* Adds references from a "source" element. A single piece of rcode may have many, depending
       on the number includes
       
       @param buffer           The Source record from which to add references  
       @param IStringStringMap Any user-defined annotation mappings
       @param JsonObject       The obejcts to which to add the annotations */
    method protected void AddReferences(buffer pSource for Source,
                                        input pUserMap as IStringStringMap,
                                        input pData as JsonObject):
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
        define variable listValue as character extent no-undo.
        define variable delim as character no-undo.
        define variable propGroup as character no-undo.
        define variable annotGroup as JsonObject no-undo.    // a set of annotations for a method/etc
        define variable valueData as JsonObject no-undo.    // a set of props with data for a single anno
        define variable jsonData as JsonObject no-undo.
        define variable groupSet as JsonArray no-undo.
        define variable valueSet as JsonArray no-undo.
        define variable iter as IIterator no-undo.
        
        define buffer lbReference for Reference.
        define buffer lbParam for Parameter-ref.
        define buffer lbCls for Class-ref.
        
        for each lbReference 
           where lbReference.Source-guid eq pSource.Source-guid
             and lbReference.File-num eq pSource.File-num
              by lbReference.Ref-seq:
            case lbReference.Reference-type:
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
                            assign jsonData   = annotGroup
                                   annotGroup = JsonPropertyHelper:GetObjectValue(
                                                    JsonPropertyHelper:GetObjectValue(pData, 'user':u, true),
                                                    propGroup, true)
                                   .
                    end.
                    else
                    if not valid-object(annotGroup) then
                        assign annotGroup = new JsonObject().
                    
                    // if there's more that one annotation with the same name, we add an object per annotation
                    // anno: {a:b, c:d}
                    // anno: null
                    // anno: [{a:b, c:d}, {f:g}, null]
                    if annotGroup:Has(annoName) then
                    case annotGroup:GetType(annoName):
                        when JsonDataType:ARRAY then
                            annotGroup:GetJsonArray(annoName)
                                      :Add(valueData).
                        
                        when JsonDataType:OBJECT or
                        when JsonDataType:NULL then
                        do:
                            assign groupSet = new JsonArray().
                            groupSet:Add(annotGroup:GetJsonObject(annoName)).
                            groupSet:Add(valueData).
                            annotGroup:Set(annoName, groupSet).
                        end.
                    end case.
                    else
                        annotGroup:Add(annoName, valueData).
                    
                    // reset annotGroup
                    if valid-object(jsonData) then
                        assign annotGroup = jsonData
                               jsonData   = ?
                               .
                end.
                
                // We don't need a name for these , since all of these are for a single 
                // program/compile unit 
                when 'compile':u then
                do:
                    if valid-object(annotGroup) then
                    do:
                        pData:Set('program':u, annotGroup).
                        assign annotGroup = ?.
                    end.
                end.
                
                when 'class':u then
                do:
                    find  lbCls
                    where lbCls.Source-guid eq lbReference.Source-guid
                      and lbCls.Ref-seq     eq lbReference.Ref-seq.
                    
                    assign extent(listValue) = ?
                           listValue         = String:Split(lbCls.Inherited-list, StringConstant:SPACE)
                           .
                    if extent(listValue) eq ? then
                        pData:AddNull('inherits':u).
                    else
                        pData:Add('inherits':u, new JsonArray(listValue)).
                    
                    assign extent(listValue) = ?
                           listValue         = String:Split(lbCls.Implements-list, StringConstant:SPACE)
                           .
                    if extent(listValue) eq ? then
                        pData:AddNull('implements':u).
                    else
                        pData:Add('implements':u, new JsonArray(listValue)).
                    
                    if valid-object(annotGroup) then
                    do:
                        pData:Set('program':u, annotGroup).
                        assign annotGroup = ?.
                    end.
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
                    if valid-object(annotGroup) then
                    do:
                        assign propGroup = lc(lbReference.reference-type)
                               propGroup = replace(propGroup, 'private-':u, '':u)
                               .
                        JsonPropertyHelper:GetObjectValue(pData, propGroup, true)
                                          :Add(lbReference.object-identifier, annotGroup).
                        assign annotGroup = ?.
                    end.
                end.
                
                // temp-tables and datasets, as long as they're PROTECTED or more open
                // otherwise they go who-knows-where
                when 'data-member':u then
                do:
                    if valid-object(annotGroup) then
                    do:
                        JsonPropertyHelper:GetObjectValue(pData, 'data':u, true)
                                          :Add(lbReference.object-identifier, annotGroup ).
                        assign annotGroup = ?.
                    end.
                end.
                
                // members that support overloading
                when 'constructor':u or
                when 'method':u then
                do:
                    if valid-object(annotGroup) then
                    do:
                        assign annoName = '':u
                               delim    = '':u
                               .
                        for each lbParam
                           where lbParam.Source-guid eq lbReference.Source-guid
                             and lbParam.Ref-seq     eq lbReference.Ref-seq
                              by lbParam.Order:
                            assign annoName = substitute('&1&4&2 &3':u,
                                                         annoName,
                                                         lbParam.Parameter-mode,
                                                         lbParam.Parameter-type,
                                                         delim)
                                  delim    = ',':u
                                  .
                        end.
                        
                        JsonPropertyHelper:GetObjectValue(pData, lc(lbReference.reference-type), true)
                                          :Add(substitute('&1(&2)':u, lbReference.object-identifier, annoName),
                                               annotGroup).
                        assign annotGroup = ?.
                    end.
                end.    // ctor/method
            end case.
        end.
        
        // If there are annotations that are written after any public things, add to the compile unit
        if valid-object(annotGroup) then
        do:
            assign extent(propNames) = ?
                   propNames         = annotGroup:GetNames()
                   cnt               = extent(propNames)
                   valueData         = JsonPropertyHelper:GetObjectValue(pData, 'program':u, true)
                   .
            do loop = 1 to cnt:
                valueData:Add(string(propNames[loop]),
                              annotGroup:GetJsonObject(string(propNames[loop]))).
            end. 
        end.
    end method.
end class.
