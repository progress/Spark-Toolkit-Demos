/*------------------------------------------------------------------------
    File        : getLockStats.p
    Purpose     : Return DB table lock statistics via temp-table
    Author(s)   : Dustin Grau
    Created     : Thu Nov 12 16:16:42 EST 2020
    Notes       : Must set "dictdb" alias for target DB before calling!
  ----------------------------------------------------------------------*/

block-level on error undo, throw.

define temp-table ttLock no-undo
    field UserNum      as int64
    field UserName     as character
    field DomainName   as character
    field TenantName   as character
    field DatabaseName as character
    field TableName    as character
    field LockFlags    as character
    field TransID      as int64
    field PID          as int64
    .

define input-output parameter table for ttLock.

define variable cUserName   as character no-undo.
define variable cDomainName as character no-undo.
define variable cTenantName as character no-undo.
define variable cTableName  as character no-undo.
define variable iUserNum    as int64     no-undo.
define variable iTransID    as int64     no-undo.
define variable iConnectPID as int64     no-undo.

if not connected("dictdb") then
    return. /* We cannot continue without a database. */

/* Only look for connections from PASN client types. */
for each dictdb._Connect no-lock
   where dictdb._Connect._Connect-Usr ne ?
     and dictdb._Connect._Connect-ClientType eq "PASN":
    assign
        iUserNum    = dictdb._Connect._Connect-Usr
        cUserName   = dictdb._Connect._Connect-Name
        iConnectPID = dictdb._Connect._Connect-Pid
        .

    /* Find all locks related to each connection. */
    for each dictdb._Lock no-lock
       where dictdb._Lock._Lock-Usr eq iUserNum:
        /* Get a user-friendly table name. */
        find dictdb._Trans no-lock where dictdb._Trans._Trans-Usrnum eq dictdb._Lock._Lock-Table no-error.
        assign iTransID = if available(dictdb._Trans) then dictdb._Trans._Trans-Id else ?.

        /* Get a user-friendly table name. */
        find dictdb._File no-lock where dictdb._File._File-Number eq dictdb._Lock._Lock-Table no-error.
        assign cTableName = if available(dictdb._File) then dictdb._File._File-Name else "N/A".

        assign /* Reset values for each _Lock record. */
            cDomainName = ""
            cTenantName = ""
            .

        /* Get a user-friendly domain & tenant name. */
        for first dictdb._sec-authentication-domain no-lock
            where dictdb._sec-authentication-domain._Domain-Id eq dictdb._Lock._Lock-DomainId:
            assign
                cDomainName = if dictdb._sec-authentication-domain._Domain-Name eq ? then "N/A" else dictdb._sec-authentication-domain._Domain-Name
                cTenantName = if dictdb._sec-authentication-domain._Tenant-Name eq ? then "N/A" else dictdb._sec-authentication-domain._Tenant-Name
                .
        end. /* for first _sec-authentication-domain */

        create ttLock.
        assign
            ttLock.UserNum      = iUserNum
            ttLock.UserName     = cUserName
            ttLock.DomainName   = cDomainName
            ttLock.TenantName   = cTenantName
            ttLock.DatabaseName = pdbname("dictdb")
            ttLock.TableName    = cTableName
            ttLock.TransID      = iTransID
            ttLock.LockFlags    = dictdb._Lock._Lock-flags
            ttLock.PID          = iConnectPID
            .
        release ttLock no-error.
    end. /* for each _Lock */
end. /* for each _Connect */
