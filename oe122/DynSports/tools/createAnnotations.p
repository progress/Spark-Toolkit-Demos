/*------------------------------------------------------------------------
    File        : createAnnotations.p
    Purpose     : Reads XML-XREF data into a ProDataset and generates JSON
                  files with annotation data 
    Author(s)   : pjudge & dugrau
    Created     : 2020-05-06
    Notes       :
  ----------------------------------------------------------------------*/
block-level on error undo, throw.

using OpenEdge.Core.Util.XrefParser from propath.
using Progress.Json.ObjectModel.* from propath.
using OpenEdge.Core.Collections.* from propath.
using Spark.Util.* from propath.

define variable cStartDir    as character        no-undo.
define variable cOutFolder   as character        no-undo initial "Deploy/Conf".
define variable cXrefTemp    as character        no-undo.
define variable oAnnotations as JsonObject       no-undo.
define variable oParser      as XrefParser       no-undo.
define variable oFileMap     as IStringStringMap no-undo.
define variable oOptMap      as IStringStringMap no-undo.
define variable oIter        as IIterator        no-undo.
define variable oFile        as IMapEntry        no-undo.

session:error-stack-trace = true.

/* ***************************  Functions  *************************** */

function getSourceFiles returns StringStringMap ( ):
    define variable ix         as integer         no-undo.
    define variable cRoot      as character       no-undo.
    define variable cFileName  as character       no-undo.
    define variable cFilePath  as character       no-undo.
    define variable oDirStruct as JsonArray       no-undo.
    define variable oFile      as JsonObject      no-undo.
    define variable oList      as StringStringMap no-undo.

    /* Find the PROPATH entry with "openedge" in the path. */
    ROOTBLK:
    do ix = 1 to num-entries(propath):
        if entry(ix, propath) matches "*\WEB-INF\openedge" then do:
            assign cRoot = entry(ix, propath).
            leave ROOTBLK.
        end. /* matches */
    end. /* ix */

    /* Get a recursive list of files from the specified directory. */
    assign oDirStruct = Spark.Core.Util.OSTools:recurseDir(cRoot + "\Business", true).

    /* Create a new list for names/paths. */
    assign oList = new StringStringMap().

    DIRBLOCK:
    do ix = 1 to oDirStruct:Length:
        assign oFile = oDirStruct:GetJsonObject(ix).
        assign cFileName = oFile:GetCharacter("FileName").
        if cFileName matches "*.cls" or cFileName matches "*.p" then do:
            assign cFilePath = oFile:GetCharacter("FullPath").
            oList:Put(cFileName, cFilePath).
        end. /* matches */
    end. /* ix */

    return oList.
end function. /* getSourceFiles */

/* ***************************  Main Block  *************************** */

file-info:file-name = ".".
assign cStartDir = file-info:full-pathname.

assign oParser = new XrefParser().
oParser:Initialize().

assign oFileMap = getSourceFiles().
assign oIter = oFileMap:EntrySet:Iterator().
do while oIter:HasNext() on error undo, throw:
    /* Iterate through the .xref.xml files. */
    oFile = cast(oIter:Next(), IMapEntry).

    assign cXrefTemp = string(oFile:Value) + ".xref".
    compile value(string(oFile:Value)) xref-xml value(cXrefTemp) no-error.

    /* Process each XREF file and create an annotations JSON file. */
    oParser:ParseXref(cXrefTemp).

    finally:
        os-delete value(cXrefTemp) no-error.
    end finally.
end. /* oIter */

/* Create a set of custom groupings for certain annotations. */
oOptMap = new StringStringMap().
oOptMap:Put("openapi.openedge.entity.primarykey", "data").
oOptMap:Put("openapi.openedge.entity.foreignkey", "data").
oOptMap:Put("openapi.openedge.entity.field.property", "data").
oOptMap:Put("program FILE", "program").
oOptMap:Put("openapi.openedge.export FILE", "program").
oOptMap:Put("progress.service.resource FILE", "program").
oOptMap:Put("openapi.openedge.service", "program").
oOptMap:Put("openapi.openedge.resource.version", "program").
oOptMap:Put("openapi.openedge.resource.security", "program").

/* Generate a singular annotation file from all the XREF files parsed. */
assign oAnnotations = oParser:GetAnnotations(oOptMap).
oAnnotations:WriteFile(substitute("&1/&2/annotations.json", cStartDir, cOutFolder), yes).

finally:
    return. /* Use this so that ANT scripts can return gracefully when finished. */
end finally.
