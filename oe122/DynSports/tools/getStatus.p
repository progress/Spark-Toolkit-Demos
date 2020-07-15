/**
 * Obtains status about all running agents from PASOE instance and ABLApp.
 * Usage: getStatus.p <params>
 *  Parameter Default/Allowed
 *   Scheme   [http|https]
 *   Hostname [localhost]
 *   PAS Port [8820]
 *   UserId   [tomcat]
 *   Password [tomcat]
 *   ABL App  [SportsPASOE]
 */

using OpenEdge.Core.Assert.
using OpenEdge.Core.Assertion.AssertJson.
using OpenEdge.Core.AssertionFailedError.
using OpenEdge.Core.JsonDataTypeEnum.
using OpenEdge.Core.String.
using OpenEdge.Core.WidgetHandle.
using OpenEdge.Net.HTTP.Credentials.
using OpenEdge.Net.HTTP.HttpClient.
using OpenEdge.Net.HTTP.IHttpRequest.
using OpenEdge.Net.HTTP.IHttpResponse.
using OpenEdge.Net.HTTP.RequestBuilder.
using Progress.Json.ObjectModel.JsonObject.
using Progress.Lang.Object.
using Progress.Json.ObjectModel.ObjectModelParser.
using Progress.Json.ObjectModel.JsonArray.

define variable oReq      as IHttpRequest  no-undo.
define variable oResp     as IHttpResponse no-undo.
define variable oEntity   as Object        no-undo.
define variable lcEntity  as longchar      no-undo.
define variable oCreds    as Credentials   no-undo.
define variable cHttpUrl  as character     no-undo.
define variable oJsonResp as JsonObject    no-undo.
define variable oAgents   as JsonArray     no-undo.
define variable oAgent    as JsonObject    no-undo.
define variable oProps    as JsonObject    no-undo.
define variable oSessions as JsonArray     no-undo.
define variable oClients  as JsonArray     no-undo.
define variable oClSess   as JsonArray     no-undo.
define variable iLoop     as integer       no-undo.
define variable iLoop2    as integer       no-undo.
define variable iTotSess  as integer       no-undo.
define variable iIdle     as integer       no-undo.
define variable iMaxSess  as integer       no-undo.
define variable iClients  as integer       no-undo.
define variable iSessions as integer       no-undo.
define variable cScheme   as character     no-undo.
define variable cHost     as character     no-undo.
define variable cPort     as character     no-undo.
define variable cUserId   as character     no-undo.
define variable cPassword as character     no-undo.
define variable cAblApp   as character     no-undo.

assign
    cScheme   = "http"
    cHost     = "localhost"
    cPort     = "8820"
    cUserId   = "tomcat"
    cPassword = "tomcat"
    cAblApp   = "SportsPASOE"
    .

if num-entries(session:parameter) ge 6 then
    assign
        cScheme   = entry(1, session:parameter)
        cHost     = entry(2, session:parameter)
        cPort     = entry(3, session:parameter)
        cUserId   = entry(4, session:parameter)
        cPassword = entry(5, session:parameter)
        cAblApp   = entry(6, session:parameter)
        .
else if session:parameter ne "" then /* original method */
    assign cPort = session:parameter.

assign oCreds = new Credentials("PASOE Manager Application", cUserId, cPassword).
assign cHttpUrl = substitute("&1://&2:&3/oemanager/applications/&4/agents", cScheme, cHost, cPort, cAblApp).

message substitute("Looking for agents of &1...", cAblApp).

oReq = RequestBuilder
        :Get(cHttpUrl)
        :ContentType("application/vnd.progress+json")
        :UsingBasicAuthentication(oCreds)
        :Request.
oResp = HttpClient:Instance():Execute(oReq).
oEntity = oResp:Entity.

if type-of(oEntity, JsonObject) then
do:
    oJsonResp = cast(oEntity, JsonObject).
    oJsonResp:Write(input-output lcEntity, true).
    oAgents = oJsonResp:GetJsonObject("result"):GetJsonArray("agents").
    if oAgents:Length eq 0 then
        message "No agents running".
    else
    do iLoop = 1 to oAgents:Length:
        oAgent = oAgents:GetJsonObject(iLoop).

        /* Get sessions and count non-idle states. */
        assign cHttpUrl = substitute("&1://&2:&3/oemanager/applications/&4/agents/&5/sessions", cScheme, cHost, cPort, cAblApp, oAgent:GetCharacter("pid")).
        oReq = RequestBuilder
            :Get(cHttpUrl)
            :ContentType("application/vnd.progress+json")
            :UsingBasicAuthentication(oCreds)
            :Request.
        oResp = HttpClient:Instance():Execute(oReq).
        oEntity = oResp:Entity.
        if type-of(oEntity, JsonObject) then
        do:
            if cast(oEntity, JsonObject):Has("result") then do:
                oSessions = cast(oEntity, JsonObject):GetJsonObject("result"):GetJsonArray("AgentSession").
                assign
                    iTotSess = oSessions:Length
                    iIdle    = 0
                    .
                do iLoop2 = 1 to iTotSess:
                    if oSessions:GetJsonObject(iLoop2):GetCharacter("SessionState") ne "IDLE" then
                        assign iIdle = iIdle + 1.
                end.
                message substitute("Agent &1 [&2]: &3% Busy", oAgent:GetCharacter("pid"), oAgent:GetCharacter("state"), round((iIdle / iTotSess) * 100, 1)).
            end.
        end.
    end. /* iLoop */

    /* Get the configured max for ABLSessions. */
    assign cHttpUrl = substitute("&1://&2:&3/oemanager/applications/&4/properties", cScheme, cHost, cPort, cAblApp).
    oReq = RequestBuilder
        :Get(cHttpUrl)
        :ContentType("application/vnd.progress+json")
        :UsingBasicAuthentication(oCreds)
        :Request.
    oResp = HttpClient:Instance():Execute(oReq).
    oEntity = oResp:Entity.
    if type-of(oEntity, JsonObject) then
    do:
        if cast(oEntity, JsonObject):Has("result") then do:
            oProps = cast(oEntity, JsonObject):GetJsonObject("result").
            assign iMaxSess = integer(oProps:GetCharacter("maxABLSessionsPerAgent")).
            message substitute("&1 Max ABLSessions", iMaxSess).
        end.
    end.

    /* Get a count of client connections. */
    assign cHttpUrl = substitute("&1://&2:&3/oemanager/applications/&4/clients", cScheme, cHost, cPort, cAblApp).
    oReq = RequestBuilder
        :Get(cHttpUrl)
        :ContentType("application/vnd.progress+json")
        :UsingBasicAuthentication(oCreds)
        :Request.
    oResp = HttpClient:Instance():Execute(oReq).
    oEntity = oResp:Entity.
    if type-of(oEntity, JsonObject) then
    do:
        if cast(oEntity, JsonObject):Has("result") then do:
            oClients = cast(oEntity, JsonObject):GetJsonObject("result"):GetJsonArray("ClientConnection").
            assign iClients = oClients:Length.
            message substitute("&1 Client Connections", iClients).
        end.
    end.

    /* Get a count of client (http) sessions. */
    assign cHttpUrl = substitute("&1://&2:&3/oemanager/applications/&4/sessions", cScheme, cHost, cPort, cAblApp).
    oReq = RequestBuilder
        :Get(cHttpUrl)
        :ContentType("application/vnd.progress+json")
        :UsingBasicAuthentication(oCreds)
        :Request.
    oResp = HttpClient:Instance():Execute(oReq).
    oEntity = oResp:Entity.
    if type-of(oEntity, JsonObject) then
    do:
        if cast(oEntity, JsonObject):Has("result") then do:
            oClSess = cast(oEntity, JsonObject):GetJsonObject("result"):GetJsonArray("OEABLSession").
            assign iSessions = oClSess:Length.
            message substitute("&1 Client Sessions", iSessions).
        end.
    end.
end. /* Valid Entity */
else do:
    if valid-object(oResp) then
        message substitute("Error executing oemanager request. [&1]", oResp:ToString()).
    else
        message "Undefined response".
end.

/* Return value expected by PCT Ant task. */
return string(0).

