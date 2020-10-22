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

define variable hServer   as handle    no-undo.
define variable hPortType as handle    no-undo.
define variable cConnect  as character no-undo.
define variable cWSTarget as character no-undo initial "urn:MyTest".
define variable cWSPort   as character no-undo initial "WSTestObj".
define variable lReturn   as logical   no-undo.
define variable cScheme   as character no-undo initial "http".
define variable cHost     as character no-undo initial "localhost".
define variable cPort     as character no-undo initial "8820".
define variable cWebApp   as character no-undo initial "sports".

create server hServer.

assign cConnect = substitute("&1://&2:&3/&4/soap/wsdl?targetURI=&5", cScheme, cHost, cPort, cWebApp, cWSTarget).
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
        run WSTestObj set hPortType on hServer no-error.
        if error-status:error then
            message "Error, Return-Value:" return-value view-as alert-box.

        if valid-handle(hPortType) then
            run TestSuite in hPortType.
    end. /* do */
end. /* connected */

finally:
    if valid-object(hPortType) then
        delete object hPortType no-error.

    if valid-object(hServer) and hServer:connected() then do:
        hServer:disconnect().
        delete object hServer no-error.
    end.
end.
