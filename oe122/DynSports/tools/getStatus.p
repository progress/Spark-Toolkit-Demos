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
 *
 * Reference: https://knowledgebase.progress.com/articles/Article/P89737
 */

using OpenEdge.Core.Assert.
using OpenEdge.Core.Assertion.AssertJson.
using OpenEdge.Core.AssertionFailedError.
using OpenEdge.Core.JsonDataTypeEnum.
using OpenEdge.Core.String.
using OpenEdge.Core.WidgetHandle.
using OpenEdge.Net.HTTP.ClientBuilder.
using OpenEdge.Net.HTTP.Credentials.
using OpenEdge.Net.HTTP.IHttpClient.
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
define variable oClient   as IHttpClient   no-undo.
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
define variable iBusySess as integer       no-undo.
define variable iClients  as integer       no-undo.
define variable iSessions as integer       no-undo.
define variable cScheme   as character     no-undo initial "http".
define variable cHost     as character     no-undo initial "localhost".
define variable cPort     as character     no-undo initial "8810".
define variable cUserId   as character     no-undo initial "tomcat".
define variable cPassword as character     no-undo initial "tomcat".
define variable cAblApp   as character     no-undo initial "oepas1".

/* Check for passed-in arguments/parameters. */
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
else
    assign
        cScheme   = dynamic-function("getParameter" in source-procedure, "Scheme") when dynamic-function("getParameter" in source-procedure, "Scheme") gt ""
        cHost     = dynamic-function("getParameter" in source-procedure, "Host") when dynamic-function("getParameter" in source-procedure, "Host") gt ""
        cPort     = dynamic-function("getParameter" in source-procedure, "Port") when dynamic-function("getParameter" in source-procedure, "Port") gt ""
        cUserId   = dynamic-function("getParameter" in source-procedure, "UserID") when dynamic-function("getParameter" in source-procedure, "UserID") gt ""
        cPassword = dynamic-function("getParameter" in source-procedure, "PassWD") when dynamic-function("getParameter" in source-procedure, "PassWD") gt ""
        cAblApp   = dynamic-function("getParameter" in source-procedure, "ABLApp") when dynamic-function("getParameter" in source-procedure, "ABLApp") gt ""
        .

assign oClient = ClientBuilder:Build():Client.
assign oCreds = new Credentials("PASOE Manager Application", cUserId, cPassword).

/* Initial URL to obtain a list of all agents for an ABL Application. */
assign cHttpUrl = substitute("&1://&2:&3/oemanager/applications/&4/agents", cScheme, cHost, cPort, cAblApp).

message substitute("PASOE Instance: &1://&2:&3", cScheme, cHost, cPort).

message substitute("ABL Application: &1", cAblApp).

oReq = RequestBuilder
        :Get(cHttpUrl)
        :ContentType("application/vnd.progress+json")
        :UsingBasicAuthentication(oCreds)
        :Request.
oResp = oClient:Execute(oReq).
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
        oResp = oClient:Execute(oReq).
        oEntity = oResp:Entity.
        if type-of(oEntity, JsonObject) then
        do:
            if cast(oEntity, JsonObject):Has("result") then do:
                message substitute("~nAgent PID &1: &2", oAgent:GetCharacter("pid"), oAgent:GetCharacter("state")).
                message "~n~tSESSION ID~tSTATE~tSTARTED~t~t~t~tMEMORY".

                oSessions = cast(oEntity, JsonObject):GetJsonObject("result"):GetJsonArray("AgentSession").
                assign
                    iTotSess  = oSessions:Length
                    iBusySess = 0
                    .

                do iLoop2 = 1 to iTotSess:
                    if oSessions:GetJsonObject(iLoop2):GetCharacter("SessionState") ne "IDLE" then
                        assign iBusySess = iBusySess + 1.

                    message substitute("~t~t&1~t&2~t&3~t&4 KB",
                                        oSessions:GetJsonObject(iLoop2):GetInteger("SessionId"),
                                        oSessions:GetJsonObject(iLoop2):GetCharacter("SessionState"),
                                        oSessions:GetJsonObject(iLoop2):GetCharacter("StartTime"),
                                        trim(string(round(oSessions:GetJsonObject(iLoop2):GetInt64("SessionMemory") / 1024, 0), ">>>,>>>,>>>,>>9"))).
                end.

                message substitute("~tTotal Agent-Sessions: &1 (&2% Busy)", iTotSess, round((iBusySess / iTotSess) * 100, 1)).
            end.
        end.
    end. /* iLoop */

    /* Get the configured max for ABLSessions/Connections per agent, along with min/max/initial agents. */
    assign cHttpUrl = substitute("&1://&2:&3/oemanager/applications/&4/properties", cScheme, cHost, cPort, cAblApp).
    oReq = RequestBuilder
        :Get(cHttpUrl)
        :ContentType("application/vnd.progress+json")
        :UsingBasicAuthentication(oCreds)
        :Request.
    oResp = oClient:Execute(oReq).
    oEntity = oResp:Entity.
    if type-of(oEntity, JsonObject) then
    do:
        if cast(oEntity, JsonObject):Has("result") then do:
            oProps = cast(oEntity, JsonObject):GetJsonObject("result").
            message "~n". /* Empty Line */

            if oProps:Has("minAgents") then
                message substitute("Min Agents: &1", integer(oProps:GetCharacter("minAgents"))).
            if oProps:Has("maxAgents") then
                message substitute("Max Agents: &1", integer(oProps:GetCharacter("maxAgents"))).
            if oProps:Has("numInitialAgents") then
                message substitute("Initial Agents: &1", integer(oProps:GetCharacter("numInitialAgents"))).
            if oProps:Has("maxConnectionsPerAgent") then
                message substitute("Max Connections/Agent: &1", integer(oProps:GetCharacter("maxConnectionsPerAgent"))).
            if oProps:Has("maxABLSessionsPerAgent") then
                message substitute("Max ABLSessions/Agent: &1", integer(oProps:GetCharacter("maxABLSessionsPerAgent"))).
        end.
    end.

    /* Get the configured initial number of sessions along with the min available sessions. */
    assign cHttpUrl = substitute("&1://&2:&3/oemanager/applications/&4/agents/properties", cScheme, cHost, cPort, cAblApp).
    oReq = RequestBuilder
        :Get(cHttpUrl)
        :ContentType("application/vnd.progress+json")
        :UsingBasicAuthentication(oCreds)
        :Request.
    oResp = oClient:Execute(oReq).
    oEntity = oResp:Entity.
    if type-of(oEntity, JsonObject) then
    do:
        if cast(oEntity, JsonObject):Has("result") then do:
            oProps = cast(oEntity, JsonObject):GetJsonObject("result").
            message "~n". /* Empty Line */

            if oProps:Has("numInitialSessions") then
                message substitute("Initial Sessions/Agent: &1", integer(oProps:GetCharacter("numInitialSessions"))).
            if oProps:Has("minAvailableABLSessions") then
                message substitute("Min Avail Sessions/Agent: &1", integer(oProps:GetCharacter("minAvailableABLSessions"))).
        end.
    end.

    /* Get a count of client connections. */
    assign cHttpUrl = substitute("&1://&2:&3/oemanager/applications/&4/clients", cScheme, cHost, cPort, cAblApp).
    oReq = RequestBuilder
        :Get(cHttpUrl)
        :ContentType("application/vnd.progress+json")
        :UsingBasicAuthentication(oCreds)
        :Request.
    oResp = oClient:Execute(oReq).
    oEntity = oResp:Entity.
    if type-of(oEntity, JsonObject) then
    do:
        if cast(oEntity, JsonObject):Has("result") then do:
            oClients = cast(oEntity, JsonObject):GetJsonObject("result"):GetJsonArray("ClientConnection").

            assign iClients = oClients:Length.
            message substitute("~nClient Connections: &1", iClients).

            if iClients gt 0 then
                message "~tADAPTER~tREQUEST START~t~t~tELAPSED~tPROCEDURE~t~t~t~t~tREQUEST ID".

            do iLoop2 = 1 to iClients:
                /* Return similar data as /pas/pasconnections.jsp */
                message substitute("~t&1~t&2~t&3~t&4~t&5~t&6",
                                   oClients:GetJsonObject(iLoop2):GetCharacter("adapterType"),
                                   oClients:GetJsonObject(iLoop2):GetCharacter("reqStartTimeStr"),
                                   oClients:GetJsonObject(iLoop2):GetInt64("elapsedTimeMs"),
                                   oClients:GetJsonObject(iLoop2):GetCharacter("requestProcedure"),
                                   oClients:GetJsonObject(iLoop2):GetCharacter("requestID")).
            end.
        end.
    end.

    /* Get a count of client (http) sessions. */
    assign cHttpUrl = substitute("&1://&2:&3/oemanager/applications/&4/sessions", cScheme, cHost, cPort, cAblApp).
    oReq = RequestBuilder
        :Get(cHttpUrl)
        :ContentType("application/vnd.progress+json")
        :UsingBasicAuthentication(oCreds)
        :Request.
    oResp = oClient:Execute(oReq).
    oEntity = oResp:Entity.
    if type-of(oEntity, JsonObject) then
    do:
        if cast(oEntity, JsonObject):Has("result") then do:
            oClSess = cast(oEntity, JsonObject):GetJsonObject("result"):GetJsonArray("OEABLSession").

            assign iSessions = oClSess:Length.
            message substitute("~nClient (HTTP) Sessions: &1", iSessions).

            if iSessions gt 0 then
                message "~tSTATE~tLAST ACCESS~t~t~tELAPSED~tBOUND~tSESS STATE~tSESS TYPE~tADAPTER~tREQUEST ID".

            do iLoop2 = 1 to iSessions:
                /* Return similar data as /pas/passessions.jsp */
                message substitute("~t&1~t&2~t&3~t&4~t&5~t&6~t&7~t&8",
                                   oClSess:GetJsonObject(iLoop2):GetCharacter("requestState"),
                                   oClSess:GetJsonObject(iLoop2):GetCharacter("lastAccessStr"),
                                   oClSess:GetJsonObject(iLoop2):GetInt64("elapsedTimeMs"),
                                   STRING(oClSess:GetJsonObject(iLoop2):GetLogical("bound"), "YES/NO"),
                                   oClSess:GetJsonObject(iLoop2):GetCharacter("sessionState"),
                                   oClSess:GetJsonObject(iLoop2):GetCharacter("sessionType"),
                                   oClSess:GetJsonObject(iLoop2):GetCharacter("adapterType"),
                                   oClSess:GetJsonObject(iLoop2):GetCharacter("requestID")).

                /* oClSess:GetJsonObject(iLoop2):GetCharacter("sessionID")     */
                /* oClSess:GetJsonObject(iLoop2):GetCharacter("sessionPoolID") */
                /* oClSess:GetJsonObject(iLoop2):GetCharacter("ablSessionID")  */
                /* oClSess:GetJsonObject(iLoop2):GetCharacter("agentID")       */
                                   
            end.
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

