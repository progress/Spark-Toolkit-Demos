/*------------------------------------------------------------------------
    File        : ServiceTests
    Purpose     :
    Syntax      :
    Description :
    Author(s)   : dugrau@progress.com
    Created     : Fri Sept 7 14:10:52 EDT 2018
    Notes       :
  ----------------------------------------------------------------------*/

using Progress.Lang.* from propath.

block-level on error undo, throw.

class tests.ServiceTests inherits tests.SparkUnit:

    /*------------------------------------------------------------------------------
     Purpose: Start up the Spark stack similar to a session of the MSAS agent.
     Notes:
    ------------------------------------------------------------------------------*/
    @Before.
    method public void before ( ):
        this-object:StartSpark("service").
    end method.

    /*------------------------------------------------------------------------------
     Purpose: Shut down the Spark stack similar to a session of the MSAS agent.
     Notes:
    ------------------------------------------------------------------------------*/
    @After.
    method public void after ( ):
        this-object:StopSpark().
    end method.

    /*------------------------------------------------------------------------------
        Purpose:
        Notes:
    ------------------------------------------------------------------------------*/
    @Setup.
    method public void setUp ( ):
    end method.

    /*------------------------------------------------------------------------------
        Purpose:
        Notes:
    ------------------------------------------------------------------------------*/
    @TearDown.
    method public void tearDown ( ):
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Confirm the StartupManager is present and valid.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testStartupManager ( ):
        OpenEdge.Core.Assert:IsTrue(valid-object(Ccs.Common.Application:StartupManager)).
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Confirm the ServiceManager is present and valid.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testServiceManager ( ):
        OpenEdge.Core.Assert:IsTrue(valid-object(Ccs.Common.Application:ServiceManager)).
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Confirm a ClientContent object is present and valid.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testClientContext ( ):
        define variable oServiceImpl as Progress.Lang.Class no-undo.
        oServiceImpl = cast(Ccs.Common.Application:ServiceManager, Spark.Core.Manager.IServiceManager)
                            :getServiceImplementation(get-class(Spark.Core.Manager.IClientContext)).
        OpenEdge.Core.Assert:IsTrue(valid-object(oServiceImpl)).
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Confirm a Catalog (output) service is present and valid.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testCatalogService ( ):
        define variable oServiceImpl as Progress.Lang.Class no-undo.
        oServiceImpl = cast(Ccs.Common.Application:ServiceManager, Spark.Core.Manager.IServiceManager)
                            :getServiceImplementation(get-class(Spark.Core.Service.ICatalog)).
        OpenEdge.Core.Assert:IsTrue(valid-object(oServiceImpl)).
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Confirm a ServiceRegistry (DOH) is present and valid.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testServiceRegistry ( ):
        define variable oServiceImpl as Progress.Lang.Class no-undo.
        oServiceImpl = cast(Ccs.Common.Application:ServiceManager, Spark.Core.Manager.IServiceManager)
                            :getServiceImplementation(get-class(OpenEdge.Web.DataObject.IServiceRegistry)).
        OpenEdge.Core.Assert:IsTrue(valid-object(oServiceImpl)).
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Confirm a DataObjectHandler is present and valid.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testDataObjectHandler ( ):
        define variable oServiceImpl as Progress.Lang.Class no-undo.
        oServiceImpl = cast(Ccs.Common.Application:ServiceManager, Spark.Core.Manager.IServiceManager)
                            :getServiceImplementation(get-class(Progress.Web.IWebHandler)).
        OpenEdge.Core.Assert:IsTrue(valid-object(oServiceImpl)).
    end method.

end class.