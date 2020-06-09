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
&global-define domain_passkey spark01

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
        Purpose: Confirm the ServiceManager is present and valid.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testServiceManager ( ):
        OpenEdge.Core.Assert:IsTrue(valid-object(Ccs.Common.Application:ServiceManager)).
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Confirm the SessionManager is present and valid.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testSessionManager ( ):
        OpenEdge.Core.Assert:IsTrue(valid-object(Ccs.Common.Application:SessionManager)).
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Confirm a login can be performed against the service facade.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testCreateCPO ( ):
        create client-principal hCPO.
        hCPO:initialize("{&test_username}").
        hCPO:roles = "{&allowed_roles}".
        hCPO:set-property("ATTR_ENABLED", "true").
        hCPO:set-property("ATTR_LOCKED", "false").
        hCPO:set-property("ATTR_EXPIRED", "false").
        hCPO:seal("{&domain_passkey}").

        OpenEdge.Core.Assert:IsTrue(hCPO:validate-seal(audit-policy:encrypt-audit-mac-key("{&domain_passkey}"))).
    end method.

    /*------------------------------------------------------------------------------
        Purpose: Confirm a request can be performed against the service facade.
        Notes:
    ------------------------------------------------------------------------------*/
    @Test.
    method public void testFacadeService ( ):
        define variable oServiceClass as Progress.Lang.Class  no-undo.
        define variable oServiceImpl  as Progress.Lang.Object no-undo.
        define variable dtzTestDate   as datetime-tz          no-undo.
        define variable inString      as character            no-undo initial "Hello World".
        define variable inDecimal     as decimal              no-undo initial 3.1415.
        define variable inInteger     as integer              no-undo initial 12345.
        define variable outString     as character            no-undo.
        define variable outDecimal    as decimal              no-undo.
        define variable outInteger    as integer              no-undo.
        define variable outDate       as date                 no-undo.
        define variable outDTime      as datetime             no-undo.
        define variable outDTimeTZ    as datetime-tz          no-undo.

        assign oServiceClass = Progress.Lang.Class:GetClass("Business.UnitTest.Params").
        if valid-object(oServiceClass) then
            assign oServiceImpl = Ccs.Common.Application:ServiceManager:getService(oServiceClass).

        if valid-object(oServiceImpl) then do on error undo, leave:
            /* Establish identity of test user using CPO. */
            Ccs.Common.Application:SessionManager:establishRequestEnvironment(hCPO).

            assign dtzTestDate = now. /* Set a consistent date for tests. */
            cast(oServiceImpl, Business.UnitTest.Params):testPrimitives( input  inString,
                                                                         input  inDecimal,
                                                                         input  inInteger,
                                                                         input  date(dtzTestDate),
                                                                         input  datetime(date(dtzTestDate), mtime(dtzTestDate)),
                                                                         input  dtzTestDate,
                                                                         output outString,
                                                                         output outDecimal,
                                                                         output outInteger,
                                                                         output outDate,
                                                                         output outDTime,
                                                                         output outDTimeTZ).

            OpenEdge.Core.Assert:Equals(inString, outString).
            OpenEdge.Core.Assert:Equals(inDecimal, outDecimal).
            OpenEdge.Core.Assert:Equals(inInteger, outInteger).
            OpenEdge.Core.Assert:Equals(date(dtzTestDate), outDate).
            OpenEdge.Core.Assert:Equals(datetime(date(dtzTestDate), mtime(dtzTestDate)), outDTime).
            OpenEdge.Core.Assert:Equals(dtzTestDate, outDTimeTZ).

            finally:
                Ccs.Common.Application:SessionManager:endRequestEnvironment(). /* Downgrade identity. */
                Ccs.Common.Application:ServiceManager:stopServices(Spark.Core.Manager.ServiceLifeCycleEnum:request).

                delete object oServiceClass no-error.
                delete object oServiceImpl no-error.
            end finally.
        end. /* valid-object */
    end method.

end class.