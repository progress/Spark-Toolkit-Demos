/**
 * Obtains status about all running agents from PASOE instance and ABLApp.
 * Usage: getStatus.p <params>
 *  Parameter Default/Allowed
 *   Scheme   [http|https]
 *   Hostname [localhost]
 *   PAS Port [8810]
 *   UserId   [tomcat]
 *   Password [tomcat]
 *   ABL App  [oepas1]
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
using Progress.Lang.Object.
using Progress.Json.ObjectModel.ObjectModelParser.
using Progress.Json.ObjectModel.JsonObject.
using Progress.Json.ObjectModel.JsonArray.
using Progress.Json.ObjectModel.JsonDataType.

define variable oClient   as IHttpClient no-undo.
define variable oCreds    as Credentials no-undo.
define variable cHttpUrl  as character   no-undo.
define variable cInstance as character   no-undo.
define variable oJsonResp as JsonObject  no-undo.
define variable oResult   as JsonObject  no-undo.
define variable oAgents   as JsonArray   no-undo.
define variable oAgent    as JsonObject  no-undo.
define variable oSessInfo as JsonObject  no-undo.
define variable oProps    as JsonObject  no-undo.
define variable oSessions as JsonArray   no-undo.
define variable oClients  as JsonArray   no-undo.
define variable oClSess   as JsonArray   no-undo.
define variable iLoop     as integer     no-undo.
define variable iLoop2    as integer     no-undo.
define variable iTotSess  as integer     no-undo.
define variable iBusySess as integer     no-undo.
define variable iClients  as integer     no-undo.
define variable iSessions as integer     no-undo.
define variable cScheme   as character   no-undo initial "http".
define variable cHost     as character   no-undo initial "localhost".
define variable cPort     as character   no-undo initial "8810".
define variable cUserId   as character   no-undo initial "tomcat".
define variable cPassword as character   no-undo initial "tomcat".
define variable cAblApp   as character   no-undo initial "oepas1".

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
assign cInstance = substitute("&1://&2:&3", cScheme, cHost, cPort).

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
        if valid-object(oResp) and type-of(oResp:Entity, JsonObject) then
            undo, throw new Progress.Lang.AppError(string(cast(oResp:Entity, JsonObject):GetJsonText())).
        else
            undo, throw new Progress.Lang.AppError(substitute("Non-JSON response from &1", pcHttpUrl)).
    end. /* failure */

    catch err as Progress.Lang.Error:
        message substitute("Error executing OEM-API request: &1", err:GetMessage(1)).
        return new JsonObject().
    end catch.
end function. /* MakeRequest */

message substitute("PASOE Instance: &1", cInstance).
message substitute("ABL Application: &1", cAblApp).

/* Get the configured max for ABLSessions/Connections per agent, along with min/max/initial agents. */
assign cHttpUrl = substitute("&1/oemanager/applications/&2/properties", cInstance, cAblApp).
assign oJsonResp = MakeRequest(cHttpUrl). 
if valid-object(oJsonResp) then do:
    if oJsonResp:Has("result") then do:
        oProps = oJsonResp:GetJsonObject("result").

        if oProps:Has("maxAgents") and oProps:GetType("maxAgents") eq JsonDataType:String then
            message substitute("Maximum Agents: &1", oProps:GetCharacter("maxAgents")).

        if oProps:Has("minAgents") and oProps:GetType("minAgents") eq JsonDataType:String then
            message substitute("Minimum Agents: &1", oProps:GetCharacter("minAgents")).

        if oProps:Has("numInitialAgents") and oProps:GetType("numInitialAgents") eq JsonDataType:String then
            message substitute("Initial Agents: &1", oProps:GetCharacter("numInitialAgents")).

        if oProps:Has("maxConnectionsPerAgent") and oProps:GetType("maxConnectionsPerAgent") eq JsonDataType:String then
            message substitute("Max. Connections/Agent: &1", oProps:GetCharacter("maxConnectionsPerAgent")).

        if oProps:Has("maxABLSessionsPerAgent") and oProps:GetType("maxABLSessionsPerAgent") eq JsonDataType:String then
            message substitute("Max. ABLSessions/Agent: &1", oProps:GetCharacter("maxABLSessionsPerAgent")).
    end. /* result */
end. /* session manager properties */

/* Get the configured initial number of sessions along with the min available sessions. */
assign cHttpUrl = substitute("&1/oemanager/applications/&2/agents/properties", cInstance, cAblApp).
assign oJsonResp = MakeRequest(cHttpUrl). 
if valid-object(oJsonResp) then do:
    if oJsonResp:Has("result") then do:
        oProps = oJsonResp:GetJsonObject("result").

        if oProps:Has("numInitialSessions") and oProps:GetType("numInitialSessions") eq JsonDataType:String then
            message substitute("Initial Sessions/Agent: &1", oProps:GetCharacter("numInitialSessions")).

        if oProps:Has("minAvailableABLSessions") and oProps:GetType("minAvailableABLSessions") eq JsonDataType:String then
            message substitute("Min. Avail. Sess/Agent: &1", oProps:GetCharacter("minAvailableABLSessions")).
    end. /* result */
end. /* agent manager properties */

/* Initial URL to obtain a list of all agents for an ABL Application. */
assign cHttpUrl = substitute("&1/oemanager/applications/&2/agents", cInstance, cAblApp).
assign oJsonResp = MakeRequest(cHttpUrl). 
if valid-object(oJsonResp) and oJsonResp:Has("result") and oJsonResp:GetType("result") eq JsonDataType:Object then do:
    oAgents = oJsonResp:GetJsonObject("result"):GetJsonArray("agents").

    if oAgents:Length eq 0 then
        message "No agents running".
    else
    do iLoop = 1 to oAgents:Length:
        oAgent = oAgents:GetJsonObject(iLoop).

        message substitute("~nAgent PID &1: &2", oAgent:GetCharacter("pid"), oAgent:GetCharacter("state")).

&IF {&MIN_VERSION_12_2} &THEN
        /* Get the dynamic value for the available sessions of this agent (available only in 12.2 and later). */
        assign cHttpUrl = substitute("&1/oemanager/applications/&2/agents/&3/dynamicSessionLimit", cInstance, cAblApp, oAgent:GetCharacter("pid")).
        assign oJsonResp = MakeRequest(cHttpUrl). 
        if valid-object(oJsonResp) then do:
            if oJsonResp:Has("result") and oJsonResp:GetType("result") eq JsonDataType:Object then do:
                oResult = oJsonResp:GetJsonObject("result").
                if oResult:Has("AgentSessionInfo") then do:
                    oSessions = oResult:GetJsonArray("AgentSessionInfo").
                    if oSessions:Length eq 1 and oSessions:GetJsonObject(1):Has("ABLOutput") and
                       oSessions:GetJsonObject(1):GetType("ABLOutput") eq JsonDataType:Object then do:
                        oSessInfo = oSessions:GetJsonObject(1):GetJsonObject("ABLOutput").

                        /**
                         * The numABLSessions and numAvailableSession are just calculations of how many total sessions are running vs. those
                         * that are not busy. We shouldn't be concerned with these values as the data may change by the time we make the
                         * API call to get the actual session info. So it's best to just leave these off the display as #'s might not match up.
                         */
                        /**
                        if oSessInfo:Has("numABLSessions") then
                            message substitute("~tTotal ABL Sessions:~t&1", oSessInfo:GetInteger("numABLSessions")).
                        if oSessInfo:Has("numAvailableSessions") then
                            message substitute("~tAvail ABL Sessions:~t&1", oSessInfo:GetInteger("numAvailableSessions")).
                        **/

                        if oSessInfo:Has("dynmaxablsessions") and oSessInfo:GetType("dynmaxablsessions") eq JsonDataType:Number then
                            message substitute("~tDynMax ABL Sessions: &1", oSessInfo:GetInteger("dynmaxablsessions")).
                    end.
                end.
            end. /* result */
        end. /* agent manager properties */
&ENDIF

        /* Get sessions and count non-idle states. */
        assign cHttpUrl = substitute("&1/oemanager/applications/&2/agents/&3/sessions", cInstance, cAblApp, oAgent:GetCharacter("pid")).
        assign oJsonResp = MakeRequest(cHttpUrl). 
        if valid-object(oJsonResp) then do:
            if oJsonResp:Has("result") and oJsonResp:GetType("result") eq JsonDataType:Object then do:
                message "~n~tSESSION ID~tSTATE~t~tSTARTED~t~t~t~t~tMEMORY".

                oSessions = oJsonResp:GetJsonObject("result"):GetJsonArray("AgentSession").
                assign
                    iTotSess  = oSessions:Length
                    iBusySess = 0
                    .

                do iLoop2 = 1 to iTotSess:
                    if oSessions:GetJsonObject(iLoop2):GetCharacter("SessionState") ne "IDLE" then
                        assign iBusySess = iBusySess + 1.

                    message substitute("~t~t&1~t&2~t&3~t&4 KB",
                                        string(oSessions:GetJsonObject(iLoop2):GetInteger("SessionId"), ">>>9"),
                                        string(oSessions:GetJsonObject(iLoop2):GetCharacter("SessionState"), "x(10)"),
                                        oSessions:GetJsonObject(iLoop2):GetCharacter("StartTime"),
                                        trim(string(round(oSessions:GetJsonObject(iLoop2):GetInt64("SessionMemory") / 1024, 0), ">>>,>>>,>>>,>>9"))).
                end.

                message substitute("~tTotal Agent-Sessions: &1 (&2% Busy)", iTotSess, round((iBusySess / iTotSess) * 100, 1)).
                message substitute("~tAvail Agent-Sessions: &1", iTotSess - iBusySess).
            end. /* result */
        end. /* response */
    end. /* iLoop */
end. /* agents */

/* Get a count of client connections. */
assign cHttpUrl = substitute("&1/oemanager/applications/&2/clients", cInstance, cAblApp).
assign oJsonResp = MakeRequest(cHttpUrl). 
if valid-object(oJsonResp) then do:
    if oJsonResp:Has("result") and oJsonResp:GetType("result") eq JsonDataType:Object then do:
        oClients = oJsonResp:GetJsonObject("result"):GetJsonArray("ClientConnection").

        assign iClients = oClients:Length.
        message substitute("~nClient Connections: &1", iClients).

        if iClients gt 0 then
            message "~tADAPTER~tREQUEST START~t~t~tELAPSED (S)~tREQUEST ID~t~tPROCEDURE".

        do iLoop = 1 to iClients:
            /* Return similar data as /pas/pasconnections.jsp */
            message substitute("~t&1~t&2~t&3~t&4~t&5~t&6",
                               oClients:GetJsonObject(iLoop):GetCharacter("adapterType"),
                               oClients:GetJsonObject(iLoop):GetCharacter("reqStartTimeStr"),
                               string(oClients:GetJsonObject(iLoop):GetInt64("elapsedTimeMs") / 1000, ">>>,>>>,>>9"),
                               oClients:GetJsonObject(iLoop):GetCharacter("requestID"),
                               oClients:GetJsonObject(iLoop):GetCharacter("requestProcedure")).
        end. /* iLoop */
    end. /* result */
end. /* client connections */

/* Get a count of client (http) sessions. */
assign cHttpUrl = substitute("&1/oemanager/applications/&2/sessions", cInstance, cAblApp).
assign oJsonResp = MakeRequest(cHttpUrl). 
if valid-object(oJsonResp) then do:
    if oJsonResp:Has("result") and oJsonResp:GetType("result") eq JsonDataType:Object then do:
        oClSess = oJsonResp:GetJsonObject("result"):GetJsonArray("OEABLSession").

        assign iSessions = oClSess:Length.
        message substitute("~nClient (HTTP) Sessions: &1", iSessions).

        if iSessions gt 0 then
            message "~tSTATE~t~tLAST ACCESS~t~t~tELAPSED (S)~tBOUND~tSESS STATE~tSESS TYPE~tADAPTER~tREQUEST ID".

        do iLoop = 1 to iSessions:
            /* Return similar data as /pas/passessions.jsp */
            message substitute("~t&1~t&2~t&3~t&4~t&5~t&6~t&7~t&8~t&9",
                               string(oClSess:GetJsonObject(iLoop):GetCharacter("requestState"), "x(8)"),
                               oClSess:GetJsonObject(iLoop):GetCharacter("lastAccessStr"),
                               string(oClSess:GetJsonObject(iLoop):GetInt64("elapsedTimeMs") / 1000, ">>>,>>>,>>9"),
                               string(oClSess:GetJsonObject(iLoop):GetLogical("bound"), "YES/NO"),
                               string(oClSess:GetJsonObject(iLoop):GetCharacter("sessionState"), "x(10)"),
                               oClSess:GetJsonObject(iLoop):GetCharacter("sessionType"),
                               oClSess:GetJsonObject(iLoop):GetCharacter("adapterType"),
                               oClSess:GetJsonObject(iLoop):GetCharacter("requestID"),
                               oClSess:GetJsonObject(iLoop):GetCharacter("sessionID")).                              
        end. /* iLoop */
    end. /* result */
end. /* client sessions */

/* Return value expected by PCT Ant task. */
return string(0).
