/*------------------------------------------------------------------------
    File        : createDomain.p
    Purpose     : Create or update a single domain for securing API requests.
    Syntax      : Execute procedure while connected to application databases.
    Description :
    Author(s)   : Dustin Grau
    Created     : Mon Dec 19 15:06:27 EST 2016
    Notes       : Adds domain to database(s), and produces a Spark config file.
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

using Progress.Lang.Error from propath.
using OpenEdge.DataAdmin.* from propath.
using OpenEdge.DataAdmin.Error.* from propath.
using OpenEdge.DataAdmin.Lang.Collections.* from propath.

block-level on error undo, throw.

/* NOTICE: Do not use the "@" symbol in any passcodes! */
&global-define DomainName spark
&global-define DomainType _extsso
&global-define PassCode spark01
&global-define PassCodePrefix oech1::

define variable oService as DataAdminService no-undo.
define variable oDomain  as IDomain          no-undo.

define variable iDB as integer no-undo.
define variable ix as integer no-undo.
define variable iy as integer no-undo.

/* ***************************  Main Block  *************************** */

/* Apply changes to all connected databases. */
do iDB = 1 to num-dbs:
    assign oService = new DataAdminService(ldbname(iDB)).
    if valid-object(oService) then do:
        message substitute("Modifying '&1'.", ldbname(iDB)) view-as alert-box.

        assign oDomain = oService:GetDomain("{&DomainName}").
        if valid-object(oDomain) then do:
            /* Update Existing Domain */
            message substitute("Updating Domain &1", "{&DomainName}") view-as alert-box.
            assign
                oDomain:AccessCode = "{&PassCode}"
                oDomain:Description = "External Realm Domain"
                .
            oService:UpdateDomain(oDomain).
        end. /* valid-object(oDomain) */
        else do:
            /* Create New Domain */
            message substitute("Creating Domain &1", "{&DomainName}") view-as alert-box.
            assign
                oDomain = oService:NewDomain("{&DomainName}")
                oDomain:AuthenticationSystem = oService:GetAuthenticationSystem("{&DomainType}")
                oDomain:AccessCode = "{&PassCode}"
                oDomain:Description = "External Realm Domain"
                oDomain:IsEnabled = true
                .
            oService:CreateDomain(oDomain).
        end. /* not valid-object(oDomain) */

        delete object oService.
    end. /* valid-object(oService) */
end. /* iDB */

catch e as Error:
    define variable errorHandler as DataAdminErrorHandler no-undo.
    errorHandler = new DataAdminErrorHandler().
    errorHandler:Error(e).
end catch.
finally:
    delete object oDomain no-error.
end finally.
