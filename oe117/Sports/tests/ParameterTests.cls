/*------------------------------------------------------------------------
    File        : ParameterTests
    Purpose     :
    Syntax      :
    Description :
    Author(s)   : dugrau@progress.com
    Created     : Thu May 30 19:10:52 EDT 2017
    Notes       :
  ----------------------------------------------------------------------*/

&global-define test_username dev@spark
&global-define allowed_roles PSCUser,EndUser
&global-define domain_passkey oech1::23222e35397562

using Progress.Lang.* from propath.
using Progress.Json.ObjectModel.* from propath.

block-level on error undo, throw.

class tests.ParameterTests inherits tests.SparkUnit:

    define private variable hCPO as handle no-undo.

	/*------------------------------------------------------------------------------
	 Purpose: Start up the Spark stack similar to a session of the MSAS agent.
	 Notes:
	------------------------------------------------------------------------------*/
	@Before.
	method public void before ( ):
        this-object:StartSpark("parameter").
	end method.

    /*------------------------------------------------------------------------------
     Purpose: Shut down the Spark stack similar to a session of the MSAS agent.
     Notes:
    ------------------------------------------------------------------------------*/
    @After.
    method public void after ( ):
        this-object:StopSpark().

        finally:
            delete object hCPO no-error.
        end finally.
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
        Purpose: Confirm the IManager interface is present and valid.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testManager ( ):
        OpenEdge.Core.Assert:IsTrue(this-object:HasManagerInterface()).
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Confirm a DirectFacade is present and usable.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testDirectFacade ( ):
        define variable oFacade as Spark.Core.DirectFacade no-undo.
        assign oFacade = new Spark.Core.DirectFacade().
        OpenEdge.Core.Assert:IsTrue(valid-object(oFacade)).
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Confirm a login can be performed against the service facade.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testCreateCPO ( ):
        define variable oFacade  as Spark.Core.DirectFacade no-undo.
        define variable cMessage as character               no-undo.
        define variable lResult  as logical                 no-undo.
        define variable rCP      as raw                     no-undo.

        create client-principal hCPO.
        hCPO:initialize("{&test_username}").
        hCPO:roles = "{&allowed_roles}".
        hCPO:set-property("ATTR_ENABLED", "true").
        hCPO:set-property("ATTR_LOCKED", "false").
        hCPO:set-property("ATTR_EXPIRED", "false").
        hCPO:seal("{&domain_passkey}").

        OpenEdge.Core.Assert:IsTrue(hCPO:validate-seal("{&domain_passkey}")).
    end method.

end class.