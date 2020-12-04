/**
 * Enable or disable the "pulse metrics" for an instance (req. 12.2+).
 * Usage: pulseMetrics.p <params>
 *  Parameter Default/Allowed
 *   CatalinaBase [C:\OpenEdge\WRK\oepas1]
 *   ABL App  [oepas1]
 */

&GLOBAL-DEFINE MIN_VERSION_12_2 (integer(entry(1, proversion(1), ".")) eq 12 and integer(entry(2, proversion(1), ".")) ge 2)

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

define variable cQueryString  as character       no-undo.
define variable cMetricsURL   as character       no-undo initial "http://localhost:8850/web/pdo/monitor/intake/liveMetrics".
define variable cProfileURL   as character       no-undo initial "http://localhost:8850/web/pdo/monitor/intake/liveProfile".
define variable cMetricsType  as character       no-undo.
define variable cMetricsState as character       no-undo.
define variable cMetricsOpts  as character       no-undo initial "sessions,requests,calltrees,ablobjs". /* logmsgs,sessions,requests,calltrees,callstacks,ablobjs */
define variable cDescriptor   as character       no-undo.
define variable cHostIP       as character       no-undo initial "127.0.0.1".
define variable iPulseTime    as integer         no-undo initial 10.
define variable oJsonResp     as JsonObject      no-undo.
define variable oOptions      as JsonObject      no-undo.
define variable oQueryString  as StringStringMap no-undo.
define variable iLoop         as integer         no-undo.
define variable iLoop2        as integer         no-undo.
define variable iLoop3        as integer         no-undo.
define variable iCollect      as integer         no-undo.
define variable cBound        as character       no-undo.
define variable cOEJMXBinary  as character       no-undo.
define variable cCatalinaBase as character       no-undo.
define variable cAblApp       as character       no-undo initial "oepas1".

define temp-table ttAgent no-undo
    field agentID    as character
    field agentPID   as character
    field agentState as character
    .

/* Check for passed-in arguments/parameters. */
if num-entries(session:parameter) ge 6 then
    assign
        cCatalinaBase = entry(1, session:parameter)
        cAblApp       = entry(2, session:parameter)
        .
else
    assign
        cCatalinaBase = dynamic-function("getParameter" in source-procedure, "CatalinaBase") when dynamic-function("getParameter" in source-procedure, "CatalinaBase") gt ""
        cAblApp       = dynamic-function("getParameter" in source-procedure, "ABLApp") when dynamic-function("getParameter" in source-procedure, "ABLApp") gt ""
        cMetricsType  = dynamic-function("getParameter" in source-procedure, "Type") when dynamic-function("getParameter" in source-procedure, "Type") gt ""
        cMetricsState = dynamic-function("getParameter" in source-procedure, "State") when dynamic-function("getParameter" in source-procedure, "State") gt ""
        .

/* Set the name of the OEJMX binary based on operating system. */
assign cOEJMXBinary = if opsys eq "WIN32" then "oejmx.bat" else "oejmx.sh".

/* Register the queries for the OEJMX command as will be used in this utility. */
assign cDescriptor = substitute("app=&1|host=&2|name=&3", cAblApp, cHostIP, iso-date(now)).
assign oOptions = new JsonObject().
oOptions:Add("AdapterMask", "").
oOptions:Add("Coverage", true).
oOptions:Add("Statistics", true).
oOptions:Add("ProcList", "").
oOptions:Add("TestRunDescriptor", cDescriptor).
assign oQueryString = new StringStringMap().
oQueryString:Put("Agents", '~{"O":"PASOE:type=OEManager,name=AgentManager","M":["getAgents","&1"]}').
oQueryString:Put("PulseOn", '~{"O":"PASOE:type=OEManager,name=AgentManager", "M":["debugTest", "&1", "LiveDiag", "&2", &3, "&4|&5"]}').
oQueryString:Put("PulseOff", '~{"O":"PASOE:type=OEManager,name=AgentManager", "M":["debugTest", "&1", "LiveDiag", "", 0, ""]}').
oQueryString:Put("ProfilerOn", '~{"O":"PASOE:type=OEManager,name=AgentManager", "M":["pushProfilerData", "&1", "&2", "-1", "&3"]}').
oQueryString:Put("ProfilerOff", '~{"O":"PASOE:type=OEManager,name=AgentManager", "M":["pushProfilerData", "&1", "", 0, ""]}').

function InvokeJMX returns character ( input pcQueryPath as character ) forward.
function RunQuery returns JsonObject ( input pcHttpUrl as character ) forward.

/* Start with some basic header information for this report. */
message substitute("PASOE Instance: &1", cCatalinaBase).
message substitute("  Metrics Type: &1 (&2)", cMetricsType, cMetricsState).

/* Gather the list of agents for this ABL App. */
run GetAgents.

for each ttAgent no-lock
   where ttAgent.agentState eq "available":
    message substitute("~nAgent PID &1: &2", ttAgent.agentPID, ttAgent.agentState).

    assign cQueryString = "".
    case cMetricsType:
        when "pulse" then do:
            if can-do("enable,true,yes,on,1", cMetricsState) then
                assign cQueryString = substitute(oQueryString:Get("PulseOn"), ttAgent.agentPID, cMetricsURL, iPulseTime, cMetricsOpts, cDescriptor).
            else
                assign cQueryString = substitute(oQueryString:Get("PulseOff"), ttAgent.agentPID).
        end.
        when "profiler" then do:
            if can-do("enable,true,yes,on,1", cMetricsState) then
                assign cQueryString = substitute(oQueryString:Get("ProfilerOn"), ttAgent.agentPID, cProfileURL, replace(oOptions:GetJsonText(), '"', '\"')).
            else
                assign cQueryString = substitute(oQueryString:Get("ProfilerOff"), ttAgent.agentPID).
        end.
        otherwise
            message "Unknown metric type provided, task aborted.".
    end case. /* cMetricsType */

    if (cQueryString gt "") eq true then do:
        message substitute("Query: &1", cQueryString).
        assign oJsonResp = RunQuery(cQueryString).
        if valid-object(oJsonResp) then
            message substitute("Result: &1", string(oJsonResp:GetJsonText())).
    end.
end. /* for each ttAgent */

finally:
    /* Return value expected by PCT Ant task. */
    return string(0).
end finally.

/* PROCEDURES / FUNCTIONS */

function InvokeJMX returns character ( input pcQueryPath as character ):
    /**
     * Make a query again the running Java process via JMX to obtain any
     * information or set flags to control monitoring/debugging options.
     *   The -R flag removes the header, leaving only the JSON body.
     *   The -Q flag specifies the name of the query to be executed.
     *   The -O flag sets a specific location for the query output.
     * Example:
     *   oejmx.[bat|sh] -R -Q <catalina_base>/temp/<name>.qry -O <catalina_base>/temp/<output>.json
     */
    define variable cBinaryPath as character no-undo.
    define variable cOutputPath as character no-undo.
    define variable cCommand    as character no-undo.
    define variable iTime       as integer   no-undo.

    if (pcQueryPath gt "") ne true then
        undo, throw new Progress.Lang.AppError("No query path provided.", 0).

    assign iTime = mtime. /* Each request should be timestamped to avoid overlap. */
    assign cBinaryPath = substitute("&1/bin/&2", cCatalinaBase, cOEJMXBinary). /* oejmx.[bat|sh] */
    assign cOutputPath = substitute("&1.&2.json", entry(1, pcQueryPath, "."), iTime). /* Temp output file. */

    /* Construct the final command string to be executed. */
    assign cCommand = substitute("&1 -R -Q &2 -O &3", cBinaryPath, pcQueryPath, cOutputPath).

    /* Run command and report information to log file. */
    os-command no-console value(cCommand). /* Cannot use silent or no-wait here. */

    return cOutputPath. /* Return the expected location of the query output. */

    finally:
        os-delete value(pcQueryPath).
    end finally.
end function. /* InvokeJMX */

function RunQuery returns JsonObject ( input pcQueryString as character ):
    define variable cQueryPath as character         no-undo initial "temp.qry".
    define variable cOutPath   as character         no-undo.
    define variable oParser    as ObjectModelParser no-undo.
    define variable oQuery     as JsonObject        no-undo.

    do on error undo, throw
       on stop undo, retry:
        if retry then
            undo, throw new Progress.Lang.AppError("Encountered stop condition", 0).

        assign oParser = new ObjectModelParser().

        /* Output the modified string to the temporary query file. */
        assign oQuery = cast(oParser:Parse(pcQueryString), JsonObject).
        oQuery:WriteFile(cQueryPath). /* Send JSON data to disk. */

        /* Create the query for obtaining agents, and invoke the JMX command. */
        assign cOutPath = InvokeJMX(cQueryPath).

        /* Confirm output file exists, and parse the JSON payload. */
        file-info:file-name = cOutPath.
        if file-info:full-pathname ne ? then do:
            if file-info:file-size eq 0 then
                undo, throw new Progress.Lang.AppError(substitute("Encountered Empty File: &1", cOutPath), 0).

            return cast(oParser:ParseFile(cOutPath), JsonObject).
        end. /* File Exists */
    end.

    catch err as Progress.Lang.Error:
        /* Always report any errors during the API requests, and return an empty JSON object allowing remaining logic to continue. */
        message substitute("~nError executing OEM-API request: &1 [URL: &2]", err:GetMessage(1) , pcQueryString).
        return new JsonObject().
    end catch.
    finally:
        os-delete value(cOutPath).
        delete object oParser no-error.
    end finally.
end function. /* RunQuery */

/* Initial URL to obtain a list of all agents for an ABL Application. */
procedure GetAgents:
    define variable iTotAgent as integer    no-undo.
    define variable iTotSess  as integer    no-undo.
    define variable iBusySess as integer    no-undo.
    define variable dStart    as datetime   no-undo.
    define variable dCurrent  as datetime   no-undo.
    define variable oAgents   as JsonArray  no-undo.
    define variable oAgent    as JsonObject no-undo.
    define variable oSessions as JsonArray  no-undo.
    define variable oSessInfo as JsonObject no-undo.

    empty temp-table ttAgent.

    /* Capture all available agent info to a temp-table before we proceed. */
    assign cQueryString = substitute(oQueryString:Get("Agents"), cAblApp).
    assign oJsonResp = RunQuery(cQueryString).
    if valid-object(oJsonResp) and oJsonResp:Has("getAgents") and oJsonResp:GetType("getAgents") eq JsonDataType:Object then do:
        if oJsonResp:GetJsonObject("getAgents"):Has("agents") and oJsonResp:GetJsonObject("getAgents"):GetType("agents") eq JsonDataType:Array then
            oAgents = oJsonResp:GetJsonObject("getAgents"):GetJsonArray("agents").
        else
            oAgents = new JsonArray().

        assign iTotAgent = oAgents:Length.

        if oAgents:Length eq 0 then
            message "~nNo agents running".
        else
        AGENTBLK:
        do iLoop = 1 to iTotAgent
        on error undo, next AGENTBLK:
            oAgent = oAgents:GetJsonObject(iLoop).

            create ttAgent.
            assign
                ttAgent.agentID    = oAgent:GetCharacter("agentId")
                ttAgent.agentPID   = oAgent:GetCharacter("pid")
                ttAgent.agentState = oAgent:GetCharacter("state")
                .

            release ttAgent no-error.
        end. /* iLoop - Agents */
    end. /* response - Agents */
end procedure.