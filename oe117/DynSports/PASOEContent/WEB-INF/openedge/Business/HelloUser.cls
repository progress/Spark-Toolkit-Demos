 
 /*------------------------------------------------------------------------
    File        : HelloUser
    Purpose     : 
    Syntax      : 
    Description : 
    Author(s)   : Dustin Grau
    Created     : Mon Jul 30 08:59:37 EDT 2018
    Notes       : 
  ----------------------------------------------------------------------*/

using Progress.Lang.*.

block-level on error undo, throw.

class Business.HelloUser inherits Spark.Core.Service.DynamicResource use-widget-pool: 

    define public override property serviceURI as character
        initial "/web/api/common" no-undo get.
        protected set.

    define public override property resourceName as character
        initial "hello" no-undo get.
        protected set.

    method public override void initialize ( ):
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "SayHelloUser", "user", "get").
    end method. /* initialize */

    method public void SayHelloUser ( output greeting as character ):
        define variable oPrincipal as OpenEdge.Security.Principal no-undo.
        assign oPrincipal = OpenEdge.Security.Principal:Import(session:current-request-info).
        assign greeting = substitute("Hello &1",
        oPrincipal:Token:user-id).
        delete object oPrincipal no-error.
    end method.

end class.