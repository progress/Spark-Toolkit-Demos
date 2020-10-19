/*------------------------------------------------------------------------
    File        : testSoap.p
    Purpose     : Test remote SOAP connections for the instance.
    Description :
    Author(s)   : dugrau
    Created     : Wed Aug 21 11:38:52 EST 2019
    Notes       :
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

using Progress.Lang.*.
using Progress.Json.ObjectModel.*.

block-level on error undo, throw.

/* ***************************  Main Block  *************************** */

define variable hServer  as handle    no-undo.
define variable hService as handle    no-undo.
define variable cConnect as character no-undo.
define variable cWSPort  as character no-undo initial "WSTestObj".
define variable lReturn  as logical   no-undo.
define variable cScheme  as character no-undo initial "http".
define variable cHost    as character no-undo initial "localhost".
define variable cPort    as character no-undo initial "8810".

assign
    cScheme   = dynamic-function("getParameter" in source-procedure, "scheme") when dynamic-function("getParameter" in source-procedure, "scheme") gt ""
    cHost     = dynamic-function("getParameter" in source-procedure, "host") when dynamic-function("getParameter" in source-procedure, "host") gt ""
    cPort     = dynamic-function("getParameter" in source-procedure, "port") when dynamic-function("getParameter" in source-procedure, "port") gt ""
    .

create server hServer.

assign cConnect = substitute("&1://&2:&3/soap/wsdl?targetURI=&4", cScheme, cHost, cPort, "urn:test").

assign cConnect = substitute("-WSDL '&1' -Port &2", cConnect, cWSPort).
assign lReturn = hServer:connect(cConnect) no-error.
if error-status:error then
    message error-status:get-message(1) view-as alert-box.

if not lReturn then
    message "Failed to connect to SOAP server: " + cConnect view-as alert-box.

if hServer:connected() then do:
    define variable cGreeting as character no-undo.

    message "Connected to SOAP server: " + cConnect view-as alert-box.

    do stop-after 20 on stop undo, leave:
        run value(cPort) set hService on hServer no-error.
        if error-status:error then
            message "Error, Return-Value:" return-value view-as alert-box.

        if valid-handle(hService) then
            run Business_HelloProc in hService ( output cGreeting ).
/*            run HelloProc in hService ( input "World", output cGreeting ).*/

        message "Greeting:" cGreeting view-as alert-box.
    end. /* do */
end. /* connected */

finally:
    delete object hService no-error.
    hServer:disconnect().
    delete object hServer no-error.
end.
