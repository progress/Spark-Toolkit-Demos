/*------------------------------------------------------------------------
    File        : EntityTests
    Purpose     :
    Description :
    Author(s)   : pjudge
    Created     : Mon Jun 18 10:05:30 EDT 2018
    Notes       :
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

using Ccs.BusinessLogic.* from propath.
using OpenEdge.BusinessLogic.Filter.* from propath.
using OpenEdge.BusinessLogic.Query.* from propath.
using OpenEdge.Core.String from propath.
using OpenEdge.Web.DataObject.* from propath.
using Progress.Lang.* from propath.
using Progress.Json.ObjectModel.* from propath.
using Spark.Core.Manager.ICatalogManager from propath.

block-level on error undo, throw.

class tests.EntityTests inherits tests.SparkUnit:

    define private variable oCatalogManager as ICatalogManager   no-undo.
    define private variable oServices       as DataObjectService no-undo extent.

    /*------------------------------------------------------------------------------
     Purpose: Start up the Spark stack similar to a session of the MSAS agent.
     Notes:
    ------------------------------------------------------------------------------*/
    @Before.
    method public void before ( ):
        this-object:StartSpark("service").

        assign oCatalogManager = cast(this-object:GetManager("Spark.Core.Manager.ICatalogManager"), ICatalogManager).
    end method.

    /*------------------------------------------------------------------------------
     Purpose: Shut down the Spark stack similar to a session of the MSAS agent.
     Notes:
    ------------------------------------------------------------------------------*/
    @After.
    method public void after ( ):
        delete object oCatalogManager no-error.

        this-object:StopSpark().
    end method.

    @Test.
    method public void hasServices ( ):
        /* Services should have been created/loaded as part of the Spark startup logic run in the "before" method. */
        assign oServices = ServiceRegistry:GetServices().
        log-manager:write-message(substitute("Found &1 services in registry.", extent(oServices))).

        define variable oOps as MappedOperation no-undo extent.
        define variable iX   as integer         no-undo.
        do iX = 1 to extent(oServices):
            extent(oOps) = ?. /* Reset extent. */
            assign oOps = oServices[iX]:GetOperations().
            log-manager:write-message(substitute("Service #&1: &2 with &3 operations.", iX, oServices[iX]:Name, extent(oOps))).
        end.

        OpenEdge.Core.Assert:NonZero(extent(oServices)). /* Should be a non-zero number of services. */

        catch err as Progress.Lang.Error:
            log-manager:write-message(substitute("Error: &1", err:GetMessage(1))).
        end catch.
    end method.

    @Test.
    method public void writeMappings ( ):
        define variable iX as integer no-undo.
        do iX = 1 to extent(oServices):

        end.

        catch err as Progress.Lang.Error:
            log-manager:write-message(substitute("Error: &1", err:GetMessage(1))).
        end catch.
    end method.

end class.
