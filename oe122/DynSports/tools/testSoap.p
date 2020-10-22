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

define variable hServer    as handle         no-undo.
define variable hPortType  as handle         no-undo.
define variable cConnect   as character      no-undo.
define variable cWSTarget  as character      no-undo initial "urn:MyTest".
define variable cWSPort    as character      no-undo initial "WSTestObj".
define variable lReturn    as logical        no-undo.
define variable cScheme    as character      no-undo initial "http".
define variable cHost      as character      no-undo initial "localhost".
define variable cPort      as character      no-undo initial "8820".
define variable cWebApp    as character      no-undo initial "sports".
define variable oSoapError as SoapFaultError no-undo.

create server hServer.

assign cConnect = substitute("&1://&2:&3/&4/soap/wsdl?targetURI=&5", cScheme, cHost, cPort, cWebApp, cWSTarget).
assign cConnect = substitute("-WSDL '&1' -Port &2", cConnect, cWSPort).
assign lReturn = hServer:connect(cConnect) no-error.
if error-status:error then
    message error-status:get-message(1) view-as alert-box.

if not lReturn then
    message "Failed to connect to SOAP server: " + cConnect view-as alert-box.

if hServer:connected() then do:
    define variable cResult as character no-undo.

    message "Connected to SOAP server: " + cConnect view-as alert-box.

    do stop-after 30 on stop undo, leave:
        run WSTestObj set hPortType on hServer no-error.
        if error-status:error then
            message "Error, Return-Value:" return-value view-as alert-box.

        if valid-handle(hPortType) then
            run TestSuite in hPortType (input random(2000, 4000), output cResult).

        message "Result:" cResult view-as alert-box.

        catch err as Progress.Lang.Error:
            define variable cMessage as character no-undo.

            if err:GetClass():IsA(get-class(SoapFaultError)) then
            do:
                oSoapError = cast(err, SoapFaultError).
                if valid-handle(oSoapError:SoapFault:soap-fault-detail) then
                    cMessage = trim(substitute("&1 Soap Error: &2", cMessage, string(oSoapError:SoapFault:soap-fault-detail:get-serialized()))).
                cMessage = trim(substitute("&1 Soap Fault Code: &2", cMessage, oSoapError:SoapFault:soap-fault-code)).
                cMessage = trim(substitute("&1 Soap Fault String: &2", cMessage, oSoapError:SoapFault:soap-fault-string)).
                cMessage = trim(substitute("&1 Soap Fault Actor: &2", cMessage, oSoapError:SoapFault:soap-fault-actor)).
            end.
            message "Error:" cMessage view-as alert-box.
        end catch.
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
