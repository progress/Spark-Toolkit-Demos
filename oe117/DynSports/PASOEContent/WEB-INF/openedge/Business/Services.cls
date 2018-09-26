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
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "getDescription", "describe", "get").
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "getMappings", "mapping", "get").
    end method. /* initialize */

    method public void getDescription ( output bodyOutput as JsonObject ):
        define variable oServiceWriter as OpenAPI30ServiceWriter no-undo.

        assign oServiceWriter = new OpenAPI30ServiceWriter().
        if valid-object(oServiceWriter) then do:
            oServiceWriter:open().
            oServiceWriter:write(ServiceRegistry:GetServices()).
/*            oServiceWriter:write(URI:Parse("http://localhost:8820/sports/web/api")).*/
            oServiceWriter:close().

            assign bodyOutput = cast(oServiceWriter:Value, JsonObject).
        end.
        else
            assign bodyOutput = new JsonObject(). /* Create default object for response. */

        finally:
            delete object oServiceWriter no-error.
        end finally.
    end method. /* getDescription */

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