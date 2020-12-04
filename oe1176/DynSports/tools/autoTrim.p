/**
 * Performs an automatic trim of ABL Sessions and Agents based on total runtime and/or memory consumption.
 * Usage: autoTrim.p <params>
 *  Parameter Default/Allowed
 *   CatalinaBase [C:\OpenEdge\WRK\oepas1]
 *   ABL App  [oepas1]
 *
 * https://progresssoftware.atlassian.net/browse/OCTA-31101
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

define variable cOutFile      as character       no-undo.
define variable cOutDate      as character       no-undo.
define variable cQueryString  as character       no-undo.
define variable oJsonResp     as JsonObject      no-undo.
define variable oTemp         as JsonObject      no-undo.
define variable oQueryString  as StringStringMap no-undo.
define variable iLoop         as integer         no-undo.
define variable iLoop2        as integer         no-undo.
define variable cOEJMXBinary  as character       no-undo.
define variable cCatalinaBase as character       no-undo.
define variable cAblApp       as character       no-undo initial "oepas1".
define variable iMaxAgentTime as int64           no-undo.
define variable iMaxSessTime  as int64           no-undo.
define variable iMaxAgentMem  as int64           no-undo.
define variable iMaxSessMem   as int64           no-undo.
define variable lStopAgent    as logical         no-undo.

define temp-table ttAgent no-undo
    field agentID     as character
    field agentPID    as character
    field agentState  as character
    field startTime   as datetime-tz
    field runningTime as int64
    field memoryBytes as int64
    .

define temp-table ttAgentSession no-undo
    field agentID      as character
    field agentPID     as character
    field sessionID    as integer
    field sessionState as character
    field startTime    as datetime-tz
    field runningTime  as int64
    field memoryBytes  as int64
    field boundSession as character
    field boundReqID   as character
    .

define dataset dsAgentSession for ttAgent, ttAgentSession
    data-relation AgentID for ttAgent, ttAgentSession relation-fields(agentID,agentID) nested.

/* Check for passed-in arguments/parameters. */
if num-entries(session:parameter) ge 6 then
    assign
        cCatalinaBase = entry(1, session:parameter)
        cAblApp       = entry(2, session:parameter)
        iMaxAgentTime = int64(entry(3, session:parameter))
        iMaxSessTime  = int64(entry(4, session:parameter))
        iMaxAgentMem  = int64(entry(5, session:parameter))
        iMaxSessMem   = int64(entry(6, session:parameter))
        lStopAgent    = logical(entry(7, session:parameter))
        .
else
    assign
        cCatalinaBase = dynamic-function("getParameter" in source-procedure, "CatalinaBase") when dynamic-function("getParameter" in source-procedure, "CatalinaBase") gt ""
        cAblApp       = dynamic-function("getParameter" in source-procedure, "ABLApp") when dynamic-function("getParameter" in source-procedure, "ABLApp") gt ""
        iMaxAgentTime = int64(dynamic-function("getParameter" in source-procedure, "MaxAgentRuntime")) when dynamic-function("getParameter" in source-procedure, "MaxAgentRuntime") gt ""
        iMaxSessTime  = int64(dynamic-function("getParameter" in source-procedure, "MaxSessionRuntime")) when dynamic-function("getParameter" in source-procedure, "MaxSessionRuntime") gt ""
        iMaxAgentMem  = int64(dynamic-function("getParameter" in source-procedure, "MaxAgentMemKB")) when dynamic-function("getParameter" in source-procedure, "MaxAgentMemKB") gt ""
        iMaxSessMem   = int64(dynamic-function("getParameter" in source-procedure, "MaxSessionMemKB")) when dynamic-function("getParameter" in source-procedure, "MaxSessionMemKB") gt ""
        lStopAgent    = can-do("true,yes,1", dynamic-function("getParameter" in source-procedure, "StopEmptyAgent")) when dynamic-function("getParameter" in source-procedure, "StopEmptyAgent") gt ""
        .

assign cOutDate = replace(iso-date(now), ":", "_").
assign oQueryString = new StringStringMap().

/* Set the name of the OEJMX binary based on operating system. */
assign cOEJMXBinary = if opsys eq "WIN32" then "oejmx.bat" else "oejmx.sh".

/* Register the queries for the OEJMX command as will be used in this utility. */
oQueryString:Put("Agents", '~{"O":"PASOE:type=OEManager,name=AgentManager","M":["getAgents","&1"]}').
oQueryString:Put("AgentMetrics", '~{"O":"PASOE:type=OEManager,name=AgentManager","M":["getAgentMetrics","&1"]}').
oQueryString:Put("AgentSessions", '~{"O":"PASOE:type=OEManager,name=AgentManager","M":["getSessionMetrics","&1"]}').
oQueryString:Put("StopAgent", '~{"O":"PASOE:type=OEManager,name=AgentManager","M":["stopAgent","&1",10,20]}').
oQueryString:Put("StopSession", '~{"O":"PASOE:type=OEManager,name=AgentManager","M":["terminateABLSession","&1",&2,1]}').

function InvokeJMX returns character ( input pcQueryPath as character ) forward.
function RunQuery returns JsonObject ( input pcHttpUrl as character ) forward.
function FormatDecimal returns character ( input pcValue as character ) forward.
function FormatLongNumber returns character ( input pcValue as character, input plTrim as logical ) forward.
function FormatMemory returns character ( input piValue as int64, input plTrim as logical ) forward.
function FormatMsTime returns character ( input piValue as int64 ) forward.
function FormatCharAsNumber returns character ( input pcValue as character ) forward.
function FormatIntAsNumber returns character ( input piValue as integer ) forward.

assign cOutFile = substitute("agents_&1_&2.txt", cAblApp, cOutDate).
message substitute("Starting output to file: &1 ...", cOutFile).
output to value(cOutFile).

/* Start with some basic header information for this report. */
put unformatted substitute(" OpenEdge Release: &1", proversion(1)) skip.
put unformatted substitute(" Utility Executed: &1", iso-date(now)) skip.
put unformatted substitute("   PASOE Instance: &1", cCatalinaBase) skip.
put unformatted substitute("Max Agent Runtime: &1", FormatMsTime(iMaxAgentTime * 1000)) skip.
put unformatted substitute("Max Sess. Runtime: &1", FormatMsTime(iMaxSessTime * 1000)) skip.
put unformatted substitute(" Max Agent Memory: &1 KB", FormatMemory(iMaxAgentMem * 1024, false)) skip.
put unformatted substitute(" Max Sess. Memory: &1 KB", FormatMemory(iMaxSessMem * 1024, false)) skip.

/* Gather the necessary metrics. */
run GetAgents.

for each ttAgentSession exclusive-lock
      by ttAgentSession.agentPID
      by ttAgentSession.sessionID:
    /* If session is IDLE and total runtime has exceeded limits, stop the session. */
    if ttAgentSession.sessionState eq "IDLE" and
       ((ttAgentSession.runningTime / 1000) ge iMaxSessTime or (ttAgentSession.memoryBytes / 1024) ge iMaxSessMem) then do:
        put unformatted substitute("Session &1 is IDLE and beyond set limits, terminating...", ttAgentSession.sessionID).

        assign cQueryString = substitute(oQueryString:Get("StopSession"), ttAgentSession.agentPID, ttAgentSession.sessionID).
        assign oJsonResp = RunQuery(cQueryString).
        if valid-object(oJsonResp) and oJsonResp:Has("terminateABLSession") and oJsonResp:GetType("terminateABLSession") eq JsonDataType:Boolean then do:
            if oJsonResp:GetLogical("terminateABLSession") eq true then do:
                delete ttAgentSession no-error.
                put unformatted "Done." skip.
            end.
            else
                put unformatted "Session termination failed." skip.
        end.
        else
            put unformatted "Error during session termination." skip.
    end. /* IDLE and Exceeds Runtime */
end. /* for each ttAgentSession */

for each ttAgent exclusive-lock
   where not can-find(first ttAgentSession where ttAgentSession.agentPID eq ttAgent.agentPID no-lock):
    /* If there are no sessions for this agent and we are meant to stop empty agents, terminate now. */
    if lStopAgent then do:
        put unformatted substitute("Agent &1 has no running sessions, terminating...", ttAgent.agentPID).

        assign cQueryString = substitute(oQueryString:Get("StopAgent"), ttAgent.agentPID).
        assign oJsonResp = RunQuery(cQueryString).
        if valid-object(oJsonResp) and oJsonResp:Has("stopAgent") and oJsonResp:GetType("stopAgent") eq JsonDataType:Boolean then do:
            if oJsonResp:GetLogical("stopAgent") eq true then do:
                delete ttAgent no-error.
                put unformatted "Done." skip.
            end.
            else
                put unformatted "Agent termination failed." skip.
        end.
        else
            put unformatted "Error during agent termination." skip.
    end. /* lStopAgent */  
end. /* for each ttAgent */

finally:
    output close.

    message "~n". /* Denotes we completed the output, should just be an empty line on screen. */

    define variable lcText as longchar no-undo.
    define variable iLine  as integer  no-undo.
    define variable iLines as integer  no-undo.
    copy-lob from file cOutFile to lcText no-convert no-error.
    assign iLines = num-entries(lcText, "~n").
    if iLines ge 1 then
    do iLine = 1 to iLines:
        message string(entry(iLine, lcText, "~n")).
    end.

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
        put unformatted substitute("~nError executing OEM-API request: &1 [URL: &2]", err:GetMessage(1) , pcQueryString) skip.
        return new JsonObject().
    end catch.
    finally:
        os-delete value(cOutPath).
        delete object oParser no-error.
    end finally.
end function. /* RunQuery */

function FormatDecimal returns character ( input pcValue as character ):
    return trim(string(int64(pcValue) / 60000, ">>9.9")).
end function. /* FormatDecimal */

function FormatMemory returns character ( input piValue as int64, input plTrim as logical ):
    /* Should show up to 999,999,999 GB which is more than expected for any process. */
    return FormatLongNumber(string(round(piValue / 1024, 0)), plTrim).
end function. /* FormatMemory */

function FormatMsTime returns character ( input piValue as int64):
    define variable iMS  as integer no-undo.
    define variable iSec as integer no-undo.
    define variable iMin as integer no-undo.
    define variable iHr  as integer no-undo.

    assign iMS = piValue modulo 1000.
    assign piValue = (piValue - iMS) / 1000.
    assign iSec = piValue modulo 60.
    assign piValue = (piValue - iSec) / 60.
    assign iMin = piValue modulo 60.
    assign iHr = (piValue - iMin) / 60.

    return trim(string(iHr, ">99")) + ":" + string(iMin, "99") + ":" + string(iSec, "99") + "." + string(iMS, "999").
end function. /* FormatMsTime */

function FormatLongNumber returns character ( input pcValue as character, input plTrim as logical ):
    if plTrim then
        return trim(string(int64(pcValue), ">>>,>>>,>>9")).
    else
        return string(int64(pcValue), ">>>,>>>,>>9").
end function. /* FormatCharAsNumber */

function FormatCharAsNumber returns character ( input pcValue as character ):
    return string(integer(pcValue), ">>9").
end function. /* FormatCharAsNumber */

function FormatIntAsNumber returns character ( input piValue as integer ):
    return string(piValue, ">,>>9").
end function. /* FormatIntAsNumber */

/* Initial URL to obtain a list of all agents for an ABL Application. */
procedure GetAgents:
    define variable iTotAgent as integer    no-undo.
    define variable iTotSess  as integer    no-undo.
    define variable iBusySess as integer    no-undo.
    define variable dCurrent  as datetime   no-undo.
    define variable oAgents   as JsonArray  no-undo.
    define variable oAgent    as JsonObject no-undo.
    define variable oSessions as JsonArray  no-undo.
    define variable oSessInfo as JsonObject no-undo.

    empty temp-table ttAgent.
    empty temp-table ttAgentSession.

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
            put unformatted "~nNo agents running" skip.
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
                ttAgent.startTime  = now /* Placeholder */
                .

            release ttAgent no-error.
        end. /* iLoop - Agents */
    end. /* response - Agents */

    assign dCurrent = datetime(today, mtime). /* Since OEJMX is used, timestamp should be relative to the same server. */

    for each ttAgent exclusive-lock:
        /* Gather additional information for each agent after displaying a basic header. */
        put unformatted substitute("~nAgent PID &1: &2", ttAgent.agentPID, ttAgent.agentState) skip.

        /* We should only obtain additional status and metrics if the agent is available. */
        if ttAgent.agentState eq "available" then do:
            /* Get metrics about this particular agent. */
            assign cQueryString = substitute(oQueryString:Get("AgentMetrics"), ttAgent.agentPID).
            assign oJsonResp = RunQuery(cQueryString).
            if valid-object(oJsonResp) and oJsonResp:Has("getAgentMetrics") and oJsonResp:GetType("getAgentMetrics") eq JsonDataType:Object then
            do on error undo, leave:
                if oJsonResp:GetJsonObject("getAgentMetrics"):Has("AgentStatHist") and
                   oJsonResp:GetJsonObject("getAgentMetrics"):GetType("AgentStatHist") eq JsonDataType:Array and
                   oJsonResp:GetJsonObject("getAgentMetrics"):GetJsonArray("AgentStatHist"):Length ge 1 then do:
                    oTemp = oJsonResp:GetJsonObject("getAgentMetrics"):GetJsonArray("AgentStatHist"):GetJsonObject(1).

                    if oTemp:Has("OpenConnections") and oTemp:GetType("OpenConnections") eq JsonDataType:Number then
                        put unformatted substitute("~t   Open Connections:~t&1",
                                                   FormatIntAsNumber(oTemp:GetInteger("OpenConnections"))) skip.

                    if oTemp:Has("OverheadMemory") and oTemp:GetType("OverheadMemory") eq JsonDataType:Number then do:
                        assign ttAgent.memoryBytes = oTemp:GetInt64("OverheadMemory").
                        put unformatted substitute("~t    Overhead Memory: &1 KB", FormatMemory(ttAgent.memoryBytes, true)) skip.
                    end.
                end.
            end. /* response */

            /* Get sessions and count non-idle states. */
            assign cQueryString = substitute(oQueryString:Get("AgentSessions"), ttAgent.agentPID).
            assign oJsonResp = RunQuery(cQueryString).
            if valid-object(oJsonResp) and oJsonResp:Has("getSessionMetrics") and oJsonResp:GetType("getSessionMetrics") eq JsonDataType:Object then
            do on error undo, leave:
                put unformatted "~n~tSESSION ID~tSTATE~t~tSTARTED~t~t~t~tELAPSED~t~tMEMORY" skip.

                if oJsonResp:GetJsonObject("getSessionMetrics"):Has("AgentSession") then
                    oSessions = oJsonResp:GetJsonObject("getSessionMetrics"):GetJsonArray("AgentSession").
                else
                    oSessions = new JsonArray().

                assign
                    iTotSess  = oSessions:Length
                    iBusySess = 0
                    .

                do iLoop2 = 1 to iTotSess:
                    if oSessions:GetJsonObject(iLoop2):GetCharacter("SessionState") ne "IDLE" then
                        assign iBusySess = iBusySess + 1.

                    create ttAgentSession.
                    assign
                        ttAgentSession.agentID      = ttAgent.agentID
                        ttAgentSession.agentPID     = ttAgent.agentPID
                        ttAgentSession.sessionID    = oSessions:GetJsonObject(iLoop2):GetInteger("SessionId")
                        ttAgentSession.sessionState = oSessions:GetJsonObject(iLoop2):GetCharacter("SessionState")
                        ttAgentSession.startTime    = oSessions:GetJsonObject(iLoop2):GetDatetimeTZ("StartTime")
                        ttAgentSession.memoryBytes  = oSessions:GetJsonObject(iLoop2):GetInt64("SessionMemory")
                        ttAgent.memoryBytes         = ttAgent.memoryBytes + ttAgentSession.memoryBytes
                        .

                    /* Take the earliest time of any ABL Session as the "start" of the agent itself. */
                    if ttAgentSession.startTime le ttAgent.startTime then
                        assign ttAgent.startTime = ttAgentSession.startTime.

                    /* Attempt to calculate the time this agent has been running, using the current time from the server. */
                    assign ttAgent.runningTime = interval(dCurrent, datetime(date(ttAgent.startTime), mtime(ttAgent.startTime)), "milliseconds").

                    /* Attempt to calculate the time this session has been running, using the current time from the server. */
                    assign ttAgentSession.runningTime = interval(dCurrent, datetime(date(ttAgentSession.startTime), mtime(ttAgentSession.startTime)), "milliseconds").

                    put unformatted substitute("~t~t&1~t&2~t&3~t&4 &5 KB",
                                                string(ttAgentSession.sessionID, ">>>9"),
                                                string(ttAgentSession.sessionState, "x(10)"),
                                                ttAgentSession.startTime,
                                                FormatMsTime(ttAgentSession.runningTime),
                                                FormatMemory(ttAgentSession.memoryBytes, false)) skip.

                    release ttAgentSession no-error.
                end. /* iLoop2 - oSessions */

                put unformatted substitute("~tActive Agent-Sessions: &1 of &2 (&3% Busy)",
                                           iBusySess, iTotSess, if iTotSess gt 0 then round((iBusySess / iTotSess) * 100, 1) else 0) skip.
                put unformatted substitute("~tApprox. Agent Runtime: &1", FormatMsTime(ttAgent.runningTime)) skip.
                put unformatted substitute("~t Approx. Agent Memory: &1 KB", FormatMemory(ttAgent.memoryBytes, true)) skip.
            end. /* response - AgentSessions */
        end. /* agent state = available */
    end. /* for each ttAgent */
end procedure.
