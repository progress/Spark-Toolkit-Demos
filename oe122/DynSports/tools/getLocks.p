/**
 * Obtains table lock info and running programs against a PASOE instance.
 * Usage: getLocks.p <params>
 *  Parameter Default/Allowed
 *   Scheme   [http|https]
 *   Hostname [localhost]
 *   PAS Port [8810]
 *   UserId   [tomcat]
 *   Password [tomcat]
 *   ABL App  [oepas1]
 *
 */

block-level on error undo, throw.

define variable iUserNum    as int64     no-undo.
define variable cUserName   as character no-undo.
define variable cDomainName as character no-undo.
define variable cTenantName as character no-undo.
define variable iConnectPID as integer   no-undo.
define variable cTableName  as character no-undo.

message "Usr#~tUser~t~tDomain~t~tTenant~t~tTable~t~tPID".

for each _Connect no-lock
   where _Connect._Connect-Usr ne ?
     and _Connect._Connect-ClientType eq "PASN":
    assign
        iUserNum    = _Connect._Connect-Usr
        cUserName   = _Connect._Connect-Name
        iConnectPID = _Connect._Connect-Pid
        .

    for each _Lock no-lock
       where _Lock._Lock-Usr eq _Connect._Connect-usr
         and _Lock._Lock-RecId ne ?:

        for first _File no-lock
            where _File._File-Number eq _Lock._Lock-Table:
            assign cTableName = _File._File-Name.
        end.

        for first _sec-authentication-domain no-lock
            where _sec-authentication-domain._Domain-Id eq _Lock._Lock-DomainId:
            assign
                cDomainName = if _sec-authentication-domain._Domain-Name eq ? then "" else _sec-authentication-domain._Domain-Name
                cTenantName = if _sec-authentication-domain._Tenant-Name eq ? then "" else _sec-authentication-domain._Tenant-Name
                .
        end.

        message substitute("&1~t&2&3&4&5&6",
                           iUserNum,
                           string(cUserName, "x(16)"),
                           string(cDomainName, "x(16)"),
                           string(cTenantName, "x(16)"),
                           string(cTableName, "x(16)"),
                           iConnectPID).
    end.
end.

finally:
    /* Return value expected by PCT Ant task. */
    return string(0).
end finally.

