/**
 * Deletes (kills) all running agents of an ABLApp.
 * Usage: trimAgents.p <params>
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

define variable oDelResp  as IHttpResponse no-undo.
define variable oClient   as IHttpClient   no-undo.
define variable oCreds    as Credentials   no-undo.
define variable cHttpUrl  as character     no-undo.
define variable cInstance as character     no-undo.
define variable oJsonResp as JsonObject    no-undo.
define variable oAgents   as JsonArray     no-undo.
define variable oAgent    as JsonObject    no-undo.
define variable iLoop     as integer       no-undo.
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
            message substitute("Error executing oemanager request: &1", cast(oResp:Entity, JsonObject):GetJsonText()).
        else
            message substitute("Non-JSON response from &1", pcHttpUrl).

        return new JsonObject().
    end. /* failure */
end function. /* MakeRequest */

message substitute("Looking for agents of &1...", cAblApp).

/* Initial URL to obtain a list of all agents for an ABL Application. */
assign cHttpUrl = substitute("&1/oemanager/applications/&2/agents", cInstance, cAblApp).
assign oJsonResp = MakeRequest(cHttpUrl).
if valid-object(oJsonResp) then do:
    oAgents = oJsonResp:GetJsonObject("result"):GetJsonArray("agents").
    if oAgents:Length eq 0 then
        message "No agents running".
    else
    do iLoop = 1 to oAgents:Length:
        oAgent = oAgents:GetJsonObject(iLoop).

        message substitute("Stopping Agent PID &1", oAgent:GetCharacter("pid")).

        /* Gracefully stop each agent. */
        oDelResp = oClient:Execute(RequestBuilder
                                   :Delete(substitute("&1/&2", cHttpUrl, oAgent:GetCharacter("agentId")) + "?waitToFinish=120000&waitAfterStop=60000")
                                   :ContentType("application/vnd.progress+json")
                                   :UsingBasicAuthentication(oCreds)
                                   :Request).
        if type-of(oDelResp:Entity, JsonObject) then do:
            assign oJsonResp = cast(oDelResp:Entity, JsonObject).
            message substitute("~t&1: &2", oJsonResp:GetCharacter("operation"), oJsonResp:GetCharacter("outcome")).
        end.
    end. /* iLoop - agent */
end. /* agents */

/* Return value expected by PCT Ant task. */
return string(0).
