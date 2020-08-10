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

&GLOBAL-DEFINE MIN_VERSION_12_2 (integer(entry(1, proversion(0), ".")) eq 12 and integer(entry(2, proversion(0), ".")) ge 2)

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

define variable oClient   as IHttpClient   no-undo.
define variable oCreds    as Credentials   no-undo.
define variable cHttpUrl  as character     no-undo.
define variable oJsonResp as JsonObject    no-undo.
define variable oAgents   as JsonArray     no-undo.
define variable oAgent    as JsonObject    no-undo.
define variable oSessInfo as JsonObject    no-undo.
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

function MakeRequest RETURNS JsonObject ( input pcHttpUrl as character ):
    define variable oReq  as IHttpRequest  no-undo.
    define variable oResp as IHttpResponse no-undo.

    oReq = RequestBuilder
        :Get(pcHttpUrl)
        :ContentType("application/vnd.progress+json")
        :UsingBasicAuthentication(oCreds)
        :Request.
    oResp = oClient:Execute(oReq).
    if valid-object(oResp) and type-of(oResp:Entity, JsonObject) then do:
        return cast(oResp:Entity, JsonObject).
    end. /* Valid Entity */
    else do:
        if valid-object(oResp) then
            message substitute("Error executing oemanager request. [&1]", oResp:ToString()).
        else
            message substitute("Undefined response from &1", cHttpUrl).

        return new JsonObject().
    end.
end function.

message substitute("PASOE Instance: &1://&2:&3", cScheme, cHost, cPort).

message substitute("ABL Application: &1", cAblApp).

/* Get the configured max for ABLSessions/Connections per agent, along with min/max/initial agents. */
assign cHttpUrl = substitute("&1://&2:&3/oemanager/applications/&4/properties", cScheme, cHost, cPort, cAblApp).
assign oJsonResp = MakeRequest(cHttpUrl). 
if valid-object(oJsonResp) then do:
    if oJsonResp:Has("result") then do:
        oProps = oJsonResp:GetJsonObject("result").
        if oProps:Has("minAgents") then
            message substitute("Minimum Agents: &1", integer(oProps:GetCharacter("minAgents"))).
        if oProps:Has("maxAgents") then
            message substitute("Maximum Agents: &1", integer(oProps:GetCharacter("maxAgents"))).
        if oProps:Has("numInitialAgents") then
            message substitute("Initial Agents: &1", integer(oProps:GetCharacter("numInitialAgents"))).
        if oProps:Has("maxConnectionsPerAgent") then
            message substitute("Max. Connections/Agent: &1", integer(oProps:GetCharacter("maxConnectionsPerAgent"))).
        if oProps:Has("maxABLSessionsPerAgent") then
            message substitute("Max. ABLSessions/Agent: &1", integer(oProps:GetCharacter("maxABLSessionsPerAgent"))).
    end. /* result */
end. /* session manager properties */

/* Get the configured initial number of sessions along with the min available sessions. */
assign cHttpUrl = substitute("&1://&2:&3/oemanager/applications/&4/agents/properties", cScheme, cHost, cPort, cAblApp).
assign oJsonResp = MakeRequest(cHttpUrl). 
if valid-object(oJsonResp) then do:
    if oJsonResp:Has("result") then do:
        oProps = oJsonResp:GetJsonObject("result").

        if oProps:Has("numInitialSessions") then
            message substitute("Initial Sessions/Agent: &1", integer(oProps:GetCharacter("numInitialSessions"))).
        if oProps:Has("minAvailableABLSessions") then
            message substitute("Min Avail Sessions/Agent: &1", integer(oProps:GetCharacter("minAvailableABLSessions"))).
    end. /* result */
end. /* agent manager properties */

/* Initial URL to obtain a list of all agents for an ABL Application. */
assign cHttpUrl = substitute("&1://&2:&3/oemanager/applications/&4/agents", cScheme, cHost, cPort, cAblApp).
assign oJsonResp = MakeRequest(cHttpUrl). 
if valid-object(oJsonResp) then do:
    oAgents = oJsonResp:GetJsonObject("result"):GetJsonArray("agents").
    if oAgents:Length eq 0 then
        message "No agents running".
    else
    do iLoop = 1 to oAgents:Length:
        oAgent = oAgents:GetJsonObject(iLoop).

        message substitute("~nAgent PID &1: &2", oAgent:GetCharacter("pid"), oAgent:GetCharacter("state")).

&IF {&MIN_VERSION_12_2} &THEN
        /* Get the dynamic value for the available sessions (available only in 12.2 and later). */
        assign cHttpUrl = substitute("&1://&2:&3/oemanager/applications/&4/agents/&5/dynamicSessionLimit", cScheme, cHost, cPort, cAblApp, oAgent:GetCharacter("pid")).
        assign oJsonResp = MakeRequest(cHttpUrl). 
        if valid-object(oJsonResp) then do:
            if oJsonResp:Has("result") then do:
                if oJsonResp:GetJsonObject("result"):Has("AgentSessionInfo") then do:
                    oSessions = oJsonResp:GetJsonObject("result"):GetJsonArray("AgentSessionInfo").
                    if oSessions:Length eq 1 and oSessions:GetJsonObject(1):Has("ABLOutput") then do:
                        oSessInfo = oSessions:GetJsonObject(1):GetJsonObject("ABLOutput").

                        if oSessInfo:Has("numABLSessions") then
                            message substitute("~t# of ABL Sessions:~t&1", integer(oSessInfo:GetInteger("numABLSessions"))).
                        if oSessInfo:Has("numAvailableSessions") then
                            message substitute("~tAvail ABL Sessions:~t&1", integer(oSessInfo:GetInteger("numAvailableSessions"))).
                        if oSessInfo:Has("dynmaxablsessions") then
                            message substitute("~tDynMax ABL Sessions:~t&1", integer(oSessInfo:GetInteger("dynmaxablsessions"))).
                    end.
                end.
            end. /* result */
        end. /* agent manager properties */
&ENDIF

        /* Get sessions and count non-idle states. */
        assign cHttpUrl = substitute("&1://&2:&3/oemanager/applications/&4/agents/&5/sessions", cScheme, cHost, cPort, cAblApp, oAgent:GetCharacter("pid")).
        assign oJsonResp = MakeRequest(cHttpUrl). 
        if valid-object(oJsonResp) then do:
            if oJsonResp:Has("result") then do:
                message "~n~tSESSION ID~tSTATE~tSTARTED~t~t~t~tMEMORY".

                oSessions = oJsonResp:GetJsonObject("result"):GetJsonArray("AgentSession").
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
            end. /* result */
        end. /* response */
    end. /* iLoop */
end. /* agents */

/* Get a count of client connections. */
assign cHttpUrl = substitute("&1://&2:&3/oemanager/applications/&4/clients", cScheme, cHost, cPort, cAblApp).
assign oJsonResp = MakeRequest(cHttpUrl). 
if valid-object(oJsonResp) then do:
    if oJsonResp:Has("result") then do:
        oClients = oJsonResp:GetJsonObject("result"):GetJsonArray("ClientConnection").

        assign iClients = oClients:Length.
        message substitute("~nClient Connections: &1", iClients).

        if iClients gt 0 then
            message "~tADAPTER~tREQUEST START~t~t~tELAPSED~tPROCEDURE~t~t~t~t~tREQUEST ID".

        do iLoop = 1 to iClients:
            /* Return similar data as /pas/pasconnections.jsp */
            message substitute("~t&1~t&2~t&3~t&4~t&5~t&6",
                               oClients:GetJsonObject(iLoop):GetCharacter("adapterType"),
                               oClients:GetJsonObject(iLoop):GetCharacter("reqStartTimeStr"),
                               oClients:GetJsonObject(iLoop):GetInt64("elapsedTimeMs"),
                               oClients:GetJsonObject(iLoop):GetCharacter("requestProcedure"),
                               oClients:GetJsonObject(iLoop):GetCharacter("requestID")).
        end. /* iLoop */
    end. /* result */
end. /* client connections */

/* Get a count of client (http) sessions. */
assign cHttpUrl = substitute("&1://&2:&3/oemanager/applications/&4/sessions", cScheme, cHost, cPort, cAblApp).
assign oJsonResp = MakeRequest(cHttpUrl). 
if valid-object(oJsonResp) then do:
    if oJsonResp:Has("result") then do:
        oClSess = oJsonResp:GetJsonObject("result"):GetJsonArray("OEABLSession").

        assign iSessions = oClSess:Length.
        message substitute("~nClient (HTTP) Sessions: &1", iSessions).

        if iSessions gt 0 then
            message "~tSTATE~tLAST ACCESS~t~t~tELAPSED~tBOUND~tSESS STATE~tSESS TYPE~tADAPTER~tREQUEST ID".

        do iLoop = 1 to iSessions:
            /* Return similar data as /pas/passessions.jsp */
            message substitute("~t&1~t&2~t&3~t&4~t&5~t&6~t&7~t&8",
                               oClSess:GetJsonObject(iLoop):GetCharacter("requestState"),
                               oClSess:GetJsonObject(iLoop):GetCharacter("lastAccessStr"),
                               oClSess:GetJsonObject(iLoop):GetInt64("elapsedTimeMs"),
                               STRING(oClSess:GetJsonObject(iLoop):GetLogical("bound"), "YES/NO"),
                               oClSess:GetJsonObject(iLoop):GetCharacter("sessionState"),
                               oClSess:GetJsonObject(iLoop):GetCharacter("sessionType"),
                               oClSess:GetJsonObject(iLoop):GetCharacter("adapterType"),
                               oClSess:GetJsonObject(iLoop):GetCharacter("requestID")).                              
        end. /* iLoop */
    end. /* result */
end. /* client sessions */

/* Return value expected by PCT Ant task. */
return string(0).

