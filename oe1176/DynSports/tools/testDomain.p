/*------------------------------------------------------------------------
    File        : testDomain.p
    Purpose     : 
    Description : 
    Author(s)   : Dustin Grau
    Created     : Thu Jul 30 08:49:09 EDT 2020
    Notes       :
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

block-level on error undo, throw.

define variable hCPO   as handle  no-undo.
define variable lValid as logical no-undo.
define variable iX     as integer no-undo.

/* ***************************  Main Block  *************************** */

/* Create CP token with domain/passcode known to any connected databases. */
create client-principal hCPO.
hCPO:initialize("dev", "0").
hCPO:domain-name = "spark".
hCPO:seal("spark01").

assign lValid = hCPO:validate-seal(substitute("oech1::&1", audit-policy:encrypt-audit-mac-key("spark01"))) no-error.
message "Valid Seal:" lValid.
if error-status:error then
    message "Error:" error-status:get-message(1).

do ix = 1 to num-dbs:
    /* Test all connected databases to ensure the CPO (user) can be asserted. */
    message substitute("&1: &2", ldbname(iX), set-db-client(hCPO, ldbname(iX))).
end.
