/**
 * Gets agent stacks for an ABLApp.
 * Usage: getStacks.p <params>
 *  Parameter Default/Allowed
 *   Scheme   [http|https]
 *   Hostname [localhost]
 *   PAS Port [8810]
 *   UserId   [tomcat]
 *   Password [tomcat]
 *   ABL App  [oepas1]
 */

using OpenEdge.Core.JsonDataTypeEnum.
using OpenEdge.Core.Collections.StringStringMap.
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

define variable cOutFile  as character       no-undo.
define variable oDelResp  as IHttpResponse   no-undo.
define variable oClient   as IHttpClient     no-undo.
define variable oCreds    as Credentials     no-undo.
define variable cHttpUrl  as character       no-undo.
define variable cInstance as character       no-undo.
define variable oJsonResp as JsonObject      no-undo.
define variable oAgents   as JsonArray       no-undo.
define variable oAgent    as JsonObject      no-undo.
define variable oQueryURL as StringStringMap no-undo.
define variable iLoop     as integer         no-undo.
define variable cScheme   as character       no-undo initial "http".
define variable cHost     as character       no-undo initial "localhost".
define variable cPort     as character       no-undo initial "8810".
define variable cUserId   as character       no-undo initial "tomcat".
define variable cPassword as character       no-undo initial "tomcat".
define variable cAblApp   as character       no-undo initial "oepas1".

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
assign oQueryURL = new StringStringMap().

/* Register the URL's to the OEM-API endpoints as will be used in this utility. */
oQueryURL:Put("Agents", "&1/oemanager/applications/&2/agents").
oQueryURL:Put("Stacks", "&1/oemanager/applications/&2/agents/&3/stacks").

function MakeRequest returns JsonObject ( input pcHttpUrl as character ):
    define variable oReq  as IHttpRequest  no-undo.
    define variable oResp as IHttpResponse no-undo.

    if not valid-object(oClient) then
        undo, throw new Progress.Lang.AppError("No HTTP client available", 0).

    if not valid-object(oCreds) then
        undo, throw new Progress.Lang.AppError("No HTTP credentials provided", 0).

    do on error undo, throw
       on stop undo, retry:
        if retry then
            undo, throw new Progress.Lang.AppError("Encountered stop condition", 0).

        oReq = RequestBuilder
                :Get(pcHttpUrl)
                :AcceptContentType("application/vnd.progress+json")
                :UsingBasicAuthentication(oCreds)
                :Request.

        if valid-object(oReq) then
            oResp = oClient:Execute(oReq).
        else
            undo, throw new Progress.Lang.AppError("Unable to create request object", 0).
    end.

    if valid-object(oResp) and oResp:StatusCode eq 200 then do:
        /* If we have an HTTP-200 status and a JSON object as the response payload, return that. */
        if valid-object(oResp:Entity) and type-of(oResp:Entity, JsonObject) then
            return cast(oResp:Entity, JsonObject).
        else if valid-object(oResp:Entity) then
            /* Anything other than a JSON payload should be treated as an error condition. */
            undo, throw new Progress.Lang.AppError(substitute("Successful but non-JSON response object returned: &1",
                                                              oResp:Entity:GetClass():TypeName), 0).
        else
            /* Anything other than a JSON payload should be treated as an error condition. */
            undo, throw new Progress.Lang.AppError("Successful but non-JSON response object returned", 0).
    end. /* Valid Entity */
    else do:
        /* Check the resulting response and response entity if valid. */
        if valid-object(oResp) and valid-object(oResp:Entity) then
            case true:
                when type-of(oResp:Entity, OpenEdge.Core.Memptr) then
                    undo, throw new Progress.Lang.AppError(substitute("Response is a memptr of size &1",
                                                                      string(cast(oResp:Entity, OpenEdge.Core.Memptr):Size)), 0).

                when type-of(oResp:Entity, OpenEdge.Core.String) then
                    undo, throw new Progress.Lang.AppError(string(cast(oResp:Entity, OpenEdge.Core.String):Value), 0).

                when type-of(oResp:Entity, JsonObject) then
                    undo, throw new Progress.Lang.AppError(string(cast(oResp:Entity, JsonObject):GetJsonText()), 0).

                otherwise
                    undo, throw new Progress.Lang.AppError(substitute("Unknown type of response object: &1 [HTTP-&2]",
                                                                      oResp:Entity:GetClass():TypeName, oResp:StatusCode), 0).
            end case.
        else if valid-object(oResp) then
            /* Response is available, but entity is not. Just report the HTTP status code. */
            undo, throw new Progress.Lang.AppError(substitute("Unsuccessful status from server: HTTP-&1", oResp:StatusCode), 0).
        else
            /* Response is not even available (valid) so report that as an explicit case. */
            undo, throw new Progress.Lang.AppError("Invalid response from server, ", 0).
    end. /* failure */

    catch err as Progress.Lang.Error:
        /* Always report any errors during the API requests, and return an empty JSON object allowing remaining logic to continue. */
        message substitute("~nError executing OEM-API request: &1 [URL: &2]", err:GetMessage(1) , pcHttpUrl).
        return new JsonObject().
    end catch.
    finally:
        delete object oReq no-error.
        delete object oResp no-error.
    end finally.
end function. /* MakeRequest */

/* Initial URL to obtain a list of all agents for an ABL Application. */
assign cHttpUrl = substitute(oQueryURL:Get("Agents"), cInstance, cAblApp).
message substitute("Looking for Agents of &1...", cAblApp).
assign oJsonResp = MakeRequest(cHttpUrl).
if valid-object(oJsonResp) and oJsonResp:Has("result") and oJsonResp:GetType("result") eq JsonDataType:Object then do:
    oAgents = oJsonResp:GetJsonObject("result"):GetJsonArray("agents").
    if oAgents:Length eq 0 then
        message "No agents running".
    else
    AGENTBLK:
    do iLoop = 1 to oAgents:Length
    on error undo, next AGENTBLK
    on stop undo, next AGENTBLK:
        oAgent = oAgents:GetJsonObject(iLoop).

        /* Write session stack information from any available agents. */
        if oAgent:GetCharacter("state") eq "available" then do:
            assign cHttpUrl = substitute(oQueryURL:Get("Stacks"), cInstance, cAblApp, oAgent:GetCharacter("pid")).
            assign oJsonResp = MakeRequest(cHttpUrl).
            if valid-object(oJsonResp) and oJsonResp:Has("result") and oJsonResp:GetType("result") eq JsonDataType:Object then do:
                message substitute("Saving stack information for Agent PID &1...", oAgent:GetCharacter("pid")).

                if oJsonResp:GetJsonObject("result"):Has("ABLStacks") and oJsonResp:GetJsonObject("result"):GetType("ABLStacks") eq JsonDataType:Array then do:
                    assign cOutFile = substitute("agentStacks_&1_&2.json", oAgent:GetCharacter("pid"), replace(iso-date(now), ":", "_")).
                    oJsonResp:WriteFile(cOutFile, true). /* Write entire response to disk. */
                    message substitute("~tStack data written to &1", cOutFile).
                end.
            end. /* stacks */
        end. /* agent state = available */
        else
            message substitute("Agent PID &1 not AVAILABLE, skipping stacks.", oAgent:GetCharacter("pid")).
    end. /* iLoop - agent */
end. /* agents */

finally:
    /* Return value expected by PCT Ant task. */
    return string(0).
end finally.

