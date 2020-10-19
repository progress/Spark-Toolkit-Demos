/*------------------------------------------------------------------------
    File        : testApsv.p
    Purpose     : Test remote APSV connections for the instance.
    Description :
    Author(s)   : dugrau
    Created     : Wed Mar 02 15:38:52 EST 2016
    Notes       :
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

using Progress.Lang.*.
using Progress.Json.ObjectModel.*.

block-level on error undo, throw.

/* ***************************  Main Block  *************************** */

define variable hServer  as handle    no-undo.
define variable hProc    as handle    no-undo.
define variable cConnect as character no-undo.
define variable lReturn  as logical   no-undo.

create server hServer.

/*assign cConnect = substitute("http://&1:&2@&3:&4/apsv", "apsvuser", "secret", "localhost", "8830").*/
assign cConnect = substitute("http://&1:&2/sports/apsv", "localhost", "8830").

assign cConnect = substitute("-URL &1 -sessionModel Session-free", cConnect).
assign lReturn = hServer:connect(cConnect) no-error.
if error-status:error then
    message error-status:get-message(1) view-as alert-box.

if not lReturn then
    message "Failed to connect to AppServer: " + cConnect view-as alert-box.

if hServer:connected() then do:
    define variable cGreeting as character no-undo.
    define variable hCPO      as handle    no-undo.

    message "Connected to AppServer: " + cConnect view-as alert-box.

/*    if valid-object(session:current-request-info) then                                             */
/*        hServer:request-info:SetClientPrincipal(session:current-request-info:GetClientPrincipal()).*/

    create client-principal hCPO.
    hCPO:initialize("dev", "0").
    hCPO:domain-name = "spark".
    hCPO:seal("spark01").
    hServer:request-info:SetClientPrincipal(hCPO).

    do stop-after 30 on stop undo, leave:
        run Business/HelloProc.p on server hServer single-run set hProc no-error.
        if error-status:error then
            message "Error, Return-Value:" return-value view-as alert-box.

        if valid-handle(hProc) then
            run sayHello in hProc ( input "World", output cGreeting ).

        message "Greeting:" cGreeting view-as alert-box.
    end. /* do */

    delete object hCPO no-error.
end. /* connected */

finally:
    delete object hProc no-error.
    hServer:disconnect().
    delete object hServer no-error.

    /* Return value expected by PCT Ant task. */
    return string(0).
end.
