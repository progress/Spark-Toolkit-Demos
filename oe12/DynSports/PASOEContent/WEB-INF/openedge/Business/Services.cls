/*------------------------------------------------------------------------
    File        : Services
    Purpose     : 
    Syntax      : 
    Description : 
    Author(s)   : Dustin Grau
    Created     : Mon Sep 24 09:20:50 EDT 2018
    Notes       : 
  ----------------------------------------------------------------------*/

using Progress.Lang.* from propath.
using OpenEdge.Net.URI from propath.
using OpenEdge.Net.HTTP.MethodEnum from propath.
using OpenEdge.Web.DataObject.* from propath.
using OpenEdge.Web.DataObject.Writer.* from propath.
using Progress.Json.ObjectModel.* from propath.

block-level on error undo, throw.

class Business.Services inherits Spark.Core.Service.DynamicResource: 

    define public override property serviceURI as character
        initial "/web/api/common" no-undo get.
        protected set.

    define public override property resourceName as character
        initial "services" no-undo get.
        protected set.

    method public override void initialize ( ):
        /* Describe any properties about invoke methods to be exposed. */
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "getCatalog", "catalog", "get").
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "getOpenAPI", "openapi", "get").
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "getMappings", "mapping", "get").
    end method. /* initialize */

    method public void getCatalog ( output bodyOutput as JsonObject ):
        define variable oServices  as DataObjectService no-undo extent.
        define variable oOperation as MappedOperation   no-undo.
        define variable oSvcArray  as JsonArray         no-undo.
        define variable cFilename  as character         no-undo.
        define variable iX         as integer           no-undo.

        /* Create a new catalog object with empty services array. */
        assign bodyOutput = new JsonObject().
        bodyOutput:Add("version", 1.5).
        bodyOutput:Add("lastModified", now).
        assign oSvcArray = new JsonArray().

        /* Obtain catalog from each registered service. */
        assign oServices = ServiceRegistry:GetServices().
        do iX = 1 to extent(oServices):
            if not valid-object(oServices[iX]:Catalog) then do:
                assign oOperation = oServices[iX]:GetOperation("/", MethodEnum:Get).
                if valid-object(oOperation) and oOperation:TargetName matches "*.json" then do:
                    assign
                        cFilename = replace(oOperation:TargetName, "$CATALINA_BASE", os-getenv("CATALINA_BASE"))
                        cFilename = replace(cFilename, "$oepas-webapp", trim(web-context:get-cgi-value("env", "CONTEXT_PATH"), "/"))
                        .
                    file-info:file-name = cFilename.
                    if file-info:full-pathname ne ? then do:
                        define variable oParser as ObjectModelParser no-undo.
                        define variable oTemp   as JsonObject        no-undo.

                        assign oParser = new ObjectModelParser().
                        assign oTemp = cast(oParser:ParseFile(file-info:full-pathname), JsonObject).
                        if oTemp:Has("services") then
                            oSvcArray:Add(oTemp:GetJsonArray("services"):GetJsonObject(1)).

                        delete object oParser no-error.
                    end. /* File Exists */
                end. /* Operation Not Available */
            end. /* No Catalog */
            else if oServices[iX]:Catalog:Has("services") then
                oSvcArray:Add(oServices[iX]:Catalog:GetJsonArray("services"):GetJsonObject(1)).
        end. /* do ix */

        /* Add services to new catalog output. */
        bodyOutput:Add("services", oSvcArray).
    end method. /* getCatalog */

    method public void getOpenAPI ( output bodyOutput as JsonObject ):
        define variable oServiceWriter as OpenAPI30ServiceWriter no-undo.

        assign oServiceWriter = new OpenAPI30ServiceWriter().
        if valid-object(oServiceWriter) then do:
            oServiceWriter:open().
            oServiceWriter:write(ServiceRegistry:GetServices()).
            oServiceWriter:write(URI:Parse("http://localhost:8820/sports/web/api")).
            oServiceWriter:close().

            assign bodyOutput = cast(oServiceWriter:Value, JsonObject).
        end.
        else
            assign bodyOutput = new JsonObject(). /* Create default object for response. */

        finally:
            delete object oServiceWriter no-error.
        end finally.
    end method. /* getOpenAPI */

    method public void getMappings ( output bodyOutput as JsonObject ):
        define variable oServiceWriter as MappingFileServiceWriter no-undo.

        assign oServiceWriter = new MappingFileServiceWriter().
        if valid-object(oServiceWriter) then do:
            oServiceWriter:open().
            oServiceWriter:write(ServiceRegistry:GetServices()).
            oServiceWriter:close().

            assign bodyOutput = cast(oServiceWriter:Value, JsonObject).
        end.
        else
            assign bodyOutput = new JsonObject(). /* Create default object for response. */

        finally:
            delete object oServiceWriter no-error.
        end finally.
    end method. /* getMappings */

end class.