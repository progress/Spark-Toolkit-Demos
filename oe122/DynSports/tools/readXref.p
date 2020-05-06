/*------------------------------------------------------------------------
    File        : readXref.p
    Purpose     : Reads XML-XREF data into a ProDataset and generates JSON
                  from the annotation data 
    Author(s)   : pjudge
    Created     : 2018-11-07
    Notes       :
  ----------------------------------------------------------------------*/
block-level on error undo, throw.

using OpenEdge.Core.Util.XrefParser from propath.
using Progress.Json.ObjectModel.* from propath.
using OpenEdge.Core.Collections.* from propath.
using Spark.Util.* from propath.

define variable cStartDir    as character        no-undo initial "D:\OpenSource\Spark-Toolkit-Demos\oe122\DynSports".
define variable cOutFolder   as character        no-undo initial "Deploy/Annotations/Business/".
define variable cXrefDir     as character        no-undo initial "xref/Business/".
define variable cXrefRoot    as character        no-undo.
define variable cTempFile    as character        no-undo.
define variable cOutFile     as character        no-undo.
define variable oAnnotations as JsonObject       no-undo.
define variable oParser      as XrefParser       no-undo.
define variable oFileMap     as IStringStringMap no-undo.
define variable oOptMap      as IStringStringMap no-undo.
define variable oIter        as IIterator        no-undo.
define variable oFile        as IMapEntry        no-undo.

session:error-stack-trace = true.

/* ***************************  Functions  *************************** */

function getFiles returns StringStringMap ( ):
    define variable ix         as integer         no-undo.
    define variable cFileName  as character       no-undo.
    define variable cFilePath  as character       no-undo.
    define variable oDirStruct as JsonArray       no-undo.
    define variable oFile      as JsonObject      no-undo.
    define variable oList      as StringStringMap no-undo.

    /* Get a recursive list of files from the specified directory. */
    assign oDirStruct = Spark.Core.Util.OSTools:recurseDir(cXrefRoot, true).

    /* Create a new list for names/paths. */
    assign oList = new StringStringMap().

    DIRBLOCK:
    do ix = 1 to oDirStruct:Length:
        assign oFile = oDirStruct:GetJsonObject(ix).
        assign cFileName = oFile:GetCharacter("FileName").
        if cFileName matches "*.xref.xml" then do:
            assign cFilePath = oFile:GetCharacter("FullPath").
            oList:Put(cFileName, cFilePath).
        end. /* matches */
    end. /* ix */

    return oList.
end function. /* getFiles */

/* ***************************  Main Block  *************************** */

/* Assemble the xref directory location. */
assign cXrefRoot = substitute("&1/&2", cStartDir, cXrefDir).

oOptMap = new StringStringMap().
oOptMap:Put("openapi.openedge.entity.primarykey", "schema").
oOptMap:Put("openapi.openedge.entity.foreignkey", "schema").
oOptMap:Put("openapi.openedge.entity.field.property", "schema").

oParser = new XrefParser().

assign oFileMap = getFiles().
assign oIter = oFileMap:EntrySet:Iterator().
do while oIter:HasNext():
    /* Iterate through the .xref.xml files. */
    oFile = cast(oIter:Next(), IMapEntry).

    /* Process each XREF file and create an annotations JSON file. */
    oParser:Initialize().
    oParser:ParseXref(string(oFile:value)).
    oAnnotations = oParser:GetAnnotations(string(oFile:value), oOptMap).
    assign cTempFile = substitute("&1/&2", cStartDir, cOutFolder) + substring(string(oFile:value), length(cXrefRoot) + 1).
    os-create-dir value(substring(cTempFile, 1, length(cTempFile) - length(string(oFile:key)))).
    assign cOutFile = replace(cTempFile, "xref.xml", "json").
    oAnnotations:WriteFile(cOutFile, yes).
end. /* oIter */

