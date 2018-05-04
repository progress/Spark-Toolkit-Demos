/*------------------------------------------------------------------------
   File        : ABLObjectsReport
   Purpose     : Utilize the OEManager or JMX tools to gather info on
                 objects which remain in memory after code execution
   Description :
   Author(s)   : Irfan Syed (isyed@progress.com), Dustin Grau (dugrau@progress.com)
   Created     : Tue Nov 28 14:07:12 EST 2017
   Notes       : Requires OpenEdge 11.7.3 or later!
 ----------------------------------------------------------------------*/

using Progress.Lang.* from propath.
using Progress.Json.ObjectModel.* from propath.
using OpenEdge.Core.Assert from propath.
using OpenEdge.Core.JsonDataTypeEnum from propath.
using OpenEdge.Core.String from propath.
using OpenEdge.Net.HTTP.Credentials from propath.
using OpenEdge.Net.HTTP.HttpClient from propath.
using OpenEdge.Net.HTTP.IHttpRequest from propath.
using OpenEdge.Net.HTTP.IHttpResponse from propath.
using OpenEdge.Net.HTTP.RequestBuilder from propath.
using OpenEdge.Net.HTTP.IAuthenticatedRequest from propath.

block-level on error undo, throw.

class Spark.Diagnostic.Util.ABLObjectsReport inherits Spark.Core.Util.Logger use-widget-pool final:

    /*** Static Properties ***/

    define protected static property AgentList as JsonArray no-undo
        get():
            /* Using a static property to allow persistence of the last list of agents obtained. */
            if not valid-object(AgentList) then
                AgentList = new JsonArray().
            return AgentList.
        end get.
        protected set.

    /*** Common Properties ***/

    define protected property CatalinaBase as character no-undo initial ""
        get():
            if CatalinaBase eq "" then do:
                file-info:filename = trim(os-getenv("CATALINA_BASE")).
                assign CatalinaBase = right-trim(replace(file-info:full-pathname, "~\", "~/"), "~/").
            end.
            return CatalinaBase.
        end get.
        private set.


    define protected property TemporaryDir as character no-undo initial ""
        get():
            if TemporaryDir eq "" then
                assign TemporaryDir = right-trim(replace(session:temp-directory, "~\", "~/"), "~/").
            return TemporaryDir.
        end get.
        private set.

    define protected property ApplicationName as character no-undo initial ""
        get():
            if ApplicationName eq "" then do:
                assign ApplicationName = trim(os-getenv("ABLAPP_NAME")).
                oLogger:Debug(substitute("Using ABLApp Name: &1", ApplicationName)).
            end.
            return ApplicationName.
        end get.
        private set.

    define protected property MetricSource as character no-undo initial "oejmx"
        get. private set.

    /*** OEManager Properties ***/

    define protected property InstanceURI as character no-undo initial ""
        get():
            if InstanceURI eq "" then do:
                assign InstanceURI = trim(os-getenv("INSTANCE_URI")).
                oLogger:Debug(substitute("Using Instance URI: &1", InstanceURI)).
            end.
            return InstanceURI.
        end get.
        private set.

    define public property ManagerRealm as character no-undo initial "PASOE Manager Application"
        get. set.

    define public property ManagerUsername as character no-undo initial "tomcat"
        get. set.

    define public property ManagerPassword as character no-undo initial "tomcat"
        get. set.

    define protected property ManagerURI as character no-undo initial "/oemanager"
        get. private set.

    define protected property GetAllAgentsURI as character no-undo initial "/applications/&1/agents"
        get. private set.

    define protected property GetAgentURI as character no-undo initial "/applications/&1/agents/&2"
        get. private set.

    define protected property GetAgentSessionURI as character no-undo initial "/applications/&1/agents/&2/sessions"
        get. private set.

    define protected property TrackObjectsOn as character no-undo initial "/trackABLObjects/true"
        get. private set.

    define protected property TrackObjectsOff as character no-undo initial "/trackABLObjects/false"
        get. private set.

    define protected property TrackingObjects as character no-undo initial "/trackingABLObjects"
        get. private set.

    define protected property GetObjectsReport as character no-undo initial "/getABLObjectsReport"
        get. private set.

    /*** OEJMX Properties ***/

    define protected property OEJMXBinary as character no-undo initial ""
        get():
            if OEJMXBinary eq "" then
                assign OEJMXBinary = if opsys eq "WIN32" then "oejmx.bat" else "oejmx.sh".
            return OEJMXBinary.
        end get.
        private set.

    define protected property AgentsQuery as character no-undo
        initial '~{"O":"PASOE:type=OEManager,name=AgentManager","M":["getAgents","&1"]~}'
        get. private set.

    define protected property TrackOnQuery as character no-undo
        initial '~{"O":"PASOE:type=OEManager,name=AgentManager","M":["trackABLObjects","&1",true]~}'
        get. private set.

    define protected property TrackOffQuery as character no-undo
        initial '~{"O":"PASOE:type=OEManager,name=AgentManager","M":["trackABLObjects","&1",false]~}'
        get. private set.

    define protected property TrackingQuery as character no-undo
        initial '~{"O":"PASOE:type=OEManager,name=AgentManager","M":["trackingABLObjects","&1"]~}'
        get. private set.

    define protected property ABLObjectsQuery as character no-undo
        initial '~{"O":"PASOE:type=OEManager,name=AgentManager","M":["getABLObjectsReport","&1"]~}'
        get. private set.


    /***** Constructor/Destructor *****/


    constructor public ABLObjectsReport ( ):
        super().

        /* Make sure a default source has been set. */
        assign this-object:MetricSource = "oejmx".
        this-object:CheckTempPath().
    end constructor.


    constructor public ABLObjectsReport ( input pcSource as character ):
        super().

        /* Set the means of obtaining metrics. */
        case pcSource:
            when "java" or
            when "oejmx" or
            when "jmx" then
                assign this-object:MetricSource = "oejmx".
            otherwise
                assign this-object:MetricSource = "oemanager".
        end case.
        this-object:CheckTempPath().
    end constructor.


    destructor public ABLObjectsReport ( ):
        delete object oLogger no-error.
    end destructor.


    /***** Private Methods *****/


    method private void CheckTempPath ( ):
        /* Make sure we have a consistent path for temporary files. */
        os-create-dir value(substitute("&1", this-object:TemporaryDir)).
        os-create-dir value(substitute("&1/metrics", this-object:TemporaryDir)).
    end method. /* CheckTempPath */


    /***** Protected Methods *****/


    method protected JsonObject InvokeAPI ( input pcRequestURI as character ):
        /**
         * Use the OEManager webapp to run the necessary queries on the PAS
         * instance. This requires use of the OEHttpClient library to make
         * an API call via REST. For environments where OEManager is not
         * available or desired, use the JMX approach.
         */

        define variable oHttpReq     as IHttpRequest  no-undo.
        define variable oHttpResp    as IHttpResponse no-undo.
        define variable oCredentials as Credentials   no-undo.

        Assert:NotNullOrEmpty(pcRequestURI). /* Must have a URL! */

        oLogger:Debug(substitute("Requesting URL: &1", pcRequestURI)).

        /* Set credentials for HTTP basic using the specific realm. */
        assign oCredentials = new Credentials(this-object:ManagerRealm,
                                              this-object:ManagerUsername,
                                              this-object:ManagerPassword).

        /* Request the necessary information via GET. */
        oHttpReq = RequestBuilder:Get(pcRequestURI)
                                 :ContentType("application/vnd.progress+json")
                                 :UsingBasicAuthentication(oCredentials)
                                 :Request.
        oHttpResp = HttpClient:Instance():Execute(oHttpReq).

        if oHttpResp:StatusCode ne 200 then do:
            oLogger:Error(substitute("Response Code was not HTTP/200: &1", string(oHttpResp:StatusCode))).
            return ?.
        end. /* Response not HTTP/200 */

        /* Make sure that entity is a true JSON object prior to casting and returning. */
        if valid-object(oHttpResp:Entity) and type-of(oHttpResp:Entity, JsonObject) then
            return cast(oHttpResp:Entity, JsonObject).

        return ?.

        catch err as Progress.Lang.Error:
            oLogger:Error(substitute("Failed while invoking &1", pcRequestURI)).
            oLogger:Error(substitute("Failed in InvokeAPI: &1", err:GetMessage(1))).
            return ?.
        end catch.
        finally:
            delete object oCredentials no-error.
            delete object oHttpReq no-error.
            delete object oHttpResp no-error.
        end finally.
    end method. /* InvokeAPI */


    method protected character InvokeJMX ( input pcQueryPath as character ):
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

        Assert:NotNullOrEmpty(pcQueryPath). /* Must have a query! */

        assign iTime = mtime. /* Each request should be timestamped. */
        assign cBinaryPath = substitute("&1/bin/&2", this-object:CatalinaBase, OEJMXBinary). /* oejmx.[bat|sh] */
        assign cOutputPath = substitute("&1.&2.json", entry(1, pcQueryPath, "."), iTime).

        /* Construct the final command string to be executed. */
        assign cCommand = substitute("&1 -R -Q &2 -O &3", cBinaryPath, pcQueryPath, cOutputPath).

        /* Run command and report information to log file. */
        oLogger:Debug(substitute("Running Command: &1", cCommand)).
        os-command no-console value(cCommand).
        oLogger:Debug(substitute("Command Finished: &1", pcQueryPath)).

        return cOutputPath. /* Return the expected location of the query output. */

        finally:
            os-delete value(pcQueryPath).
        end finally.
    end method. /* InvokeJMX */


    method protected character CreateTempQuery ( input pcQueryName as character ):
        return this-object:CreateTempQuery(pcQueryName, "").
    end method. /* CreateTempQuery */


    method protected character CreateTempQuery ( input pcQueryName as character,
                                                 input pcAgentID   as character ):
        /**
         * Create a temporary file with the proper JMX query to be executed.
         * For some queries there is a replacement necessary, which may need
         * either the application name or an agent ID value.
         */
        define variable cQueryPath   as character         no-undo initial "".
        define variable cQueryString as character         no-undo.
        define variable oParser      as ObjectModelParser no-undo.
        define variable oQuery       as JsonObject        no-undo.

        assign cQueryPath = substitute("&1/&2.qry", this-object:TemporaryDir, pcQueryName).
        assign oParser = new ObjectModelParser().

        case pcQueryName:
            when "agents" then
                assign cQueryString = substitute(this-object:AgentsQuery, this-object:ApplicationName).
            when "trackon" then
                assign cQueryString = substitute(this-object:TrackOnQuery, pcAgentID).
            when "trackoff" then
                assign cQueryString = substitute(this-object:TrackOffQuery, pcAgentID).
            when "tracking" then
                assign cQueryString = substitute(this-object:TrackingQuery, pcAgentID).
            when "ablobjects" then
                assign cQueryString = substitute(this-object:ABLObjectsQuery, pcAgentID).
        end case. /* pcQueryName */

        /* Output the modified string to the temporary query file. */
        assign oQuery = cast(oParser:Parse(cQueryString), JsonObject).
        oLogger:Debug(substitute("Writing Query: &1", cQueryPath)).
        oQuery:WriteFile(cQueryPath).

        return cQueryPath.

        finally:
            delete object oParser no-error.
            delete object oQuery no-error.
        end finally.
    end method. /* CreateTempQuery */


    /***** Public Methods *****/


    method public void GetAgents ( ):
        if this-object:MetricSource eq "oejmx" then
        do on error undo, throw:
            define variable cOutPath as character         no-undo.
            define variable oParser  as ObjectModelParser no-undo.
            define variable oResults as JsonObject        no-undo.

            /* Create the query for obtaining agents, and invoke the JMX command. */
            assign cOutPath = this-object:InvokeJMX(this-object:CreateTempQuery("agents")).

            /* Confirm output file exists, and parse the JSON payload. */
            file-info:file-name = cOutPath.
            if file-info:full-pathname ne ? then do:
                assign oParser = new ObjectModelParser().
                assign oResults = cast(oParser:ParseFile(cOutPath), JsonObject).

                if valid-object(oResults) and oResults:Has("getAgents") then do:
                    if oResults:GetJsonObject("getAgents"):Has("agents") then
                        AgentList = oResults:GetJsonObject("getAgents"):GetJsonArray("agents").
                end. /* Has Result */
            end. /* File Exists */

            finally:
                delete object oParser no-error.
                delete object oResults no-error.
                os-delete value(cOutPath).
            end finally.
        end. /* oejmx */
        else if this-object:MetricSource eq "oemanager" then
        do on error undo, throw:
            Assert:NotNullOrEmpty(this-object:InstanceURI).

            define variable cRequestURI as character  no-undo.
            define variable oRequest    as JsonObject no-undo.

            /* Request a list of agents from the OEManager webapp. */
            assign cRequestURI = substitute("&1&2&3",
                                            this-object:InstanceURI, this-object:ManagerURI,
                                            this-object:GetAllAgentsURI).

            /* Set request with PAS instance name. */
            assign cRequestURI = substitute(cRequestURI, this-object:ApplicationName).

            /* Make the request to the endpoint and parse results. */
            assign oRequest = this-object:InvokeAPI(cRequestURI).
            if valid-object(oRequest) and oRequest:Has("result") then do:
                if oRequest:GetJsonObject("result"):Has("agents") then
                    AgentList = oRequest:GetJsonObject("result"):GetJsonArray("agents").
            end. /* Has Result */

            finally:
                delete object oRequest no-error.
            end finally.
        end. /* oemanager */

        /* Log output results of request. */
        oLogger:Debug(substitute("Available Agents: &1", AgentList:GetJsonText())).

        catch err as Progress.Lang.Error:
            oLogger:Error(substitute("Error in GetAgents: &1", err:GetMessage(1))).
            undo, throw err.
        end catch.
    end method. /* GetAgents */


    method public logical TrackABLObjects ( input plEnable as logical ):
        define variable oAgent   as JsonObject no-undo.
        define variable cAgentID as character  no-undo.
        define variable iCount   as integer    no-undo.
        define variable lSuccess as logical    no-undo initial false.

        /* Make request to all agents of this ABLApp. */
        do iCount = 1 to AgentList:Length:
            /* Set request with PAS instance name and specific Agent ID. */
            assign oAgent = AgentList:GetJsonObject(iCount).
            if valid-object(oAgent) and oAgent:Has("agentId") then do:
                /* Set the tracking option for this agent. */
                assign cAgentID = oAgent:GetCharacter("agentId").
                if this-object:TrackABLObjects(cAgentID, plEnable) then
                    assign lSuccess = true.
            end. /* has agentId */
        end. /* do iCount */

        return lSuccess.
    end method. /* TrackABLObjects */


    method public logical TrackABLObjects ( input pcAgentID as character,
                                            input plEnable  as logical ):
        define variable lSuccess as logical no-undo initial false.

        Assert:NotNullOrEmpty(pcAgentID).

        if this-object:MetricSource eq "oejmx" then
        do on error undo, throw:
            define variable cQueryName as character         no-undo.
            define variable cOutPath   as character         no-undo.
            define variable oParser    as ObjectModelParser no-undo.
            define variable oResults   as JsonObject        no-undo.

            /* Create the query for tracking objects, and invoke the JMX command. */
            assign cQueryName = if plEnable then "trackon" else "trackoff".
            assign cOutPath = this-object:InvokeJMX(this-object:CreateTempQuery(cQueryName, pcAgentID)).

            /* Confirm output file exists, and parse the JSON payload. */
            file-info:file-name = cOutPath.
            if file-info:full-pathname ne ? then do:
                assign oParser = new ObjectModelParser().
                assign oResults = cast(oParser:ParseFile(cOutPath), JsonObject).

                if valid-object(oResults) and oResults:Has("trackABLObjects") then
                    assign lSuccess = (oResults:GetLogical("trackABLObjects") eq true).
            end. /* File Exists */

            finally:
                delete object oParser no-error.
                delete object oResults no-error.
                os-delete value(cOutPath).
            end finally.
        end. /* oejmx */
        else if this-object:MetricSource eq "oemanager" then
        do on error undo, throw:
            define variable cRequestURI as character  no-undo.
            define variable oRequest    as JsonObject no-undo.

            Assert:NotNullOrEmpty(this-object:InstanceURI).

            /* Set the base URL to get information for a specific agent. */
            assign cRequestURI = substitute("&1&2&3",
                                            this-object:InstanceURI, this-object:ManagerURI,
                                            this-object:GetAgentURI).

            /* Build the initial URL, to prepare to set the tracking flag. */
            assign cRequestURI = substitute(cRequestURI, this-object:ApplicationName, pcAgentID).
            if plEnable then
                /* Turn tracking on. */
                assign cRequestURI = substitute("&1&2", cRequestURI, this-object:TrackObjectsOn).
            else
                /* Turn tracking off. */
                assign cRequestURI = substitute("&1&2", cRequestURI, this-object:TrackObjectsOff).

            /* Make the request to the endpoint and parse results. */
            assign oRequest = this-object:InvokeAPI(cRequestURI).
            if valid-object(oRequest) and oRequest:Has("result") then do:
                if not oRequest:IsNull("result") then
                    assign lSuccess = (oRequest:GetLogical("result") eq true).
            end. /* Has Result */

            finally:
                delete object oRequest no-error.
            end finally.
        end. /* oemanager */

        /* Report the result of the previous request. */
        oLogger:Debug(substitute("trackABLObjects (&1): &2 = &3",
                                pcAgentID, trim(string(plEnable, "enabled/disabled")), lSuccess)).

        return lSuccess. /* Return the value from the tracking request. */

        catch err as Progress.Lang.Error:
            oLogger:Error(substitute("Error in trackABLObjects: &1", err:GetMessage(1))).
            undo, throw err.
        end catch.
    end method. /* TrackABLObjects */


    method public logical TrackingABLObjects ( input pcAgentID as character ):
        define variable lSuccess as logical no-undo initial false.

        Assert:NotNullOrEmpty(pcAgentID).

        if this-object:MetricSource eq "oejmx" then
        do on error undo, throw:
            define variable cOutPath as character         no-undo.
            define variable oParser  as ObjectModelParser no-undo.
            define variable oResults as JsonObject        no-undo.

            /* Create the query for tracking objects, and invoke the JMX command. */
            assign cOutPath = this-object:InvokeJMX(this-object:CreateTempQuery("tracking", pcAgentID)).

            /* Confirm output file exists, and parse the JSON payload. */
            file-info:file-name = cOutPath.
            if file-info:full-pathname ne ? then do:
                assign oParser = new ObjectModelParser().
                assign oResults = cast(oParser:ParseFile(cOutPath), JsonObject).

                if valid-object(oResults) and oResults:Has("trackingABLObjects") then do:
                    /* Return only a true/false value based on value available. */
                    assign lSuccess = (oResults:GetLogical("trackingABLObjects") eq true).
                end. /* Has Result */
            end. /* File Exists */

            finally:
                delete object oParser no-error.
                delete object oResults no-error.
                os-delete value(cOutPath).
            end finally.
        end. /* oejmx */
        else if this-object:MetricSource eq "oemanager" then do:
            define variable cRequestURI as character  no-undo.
            define variable oRequest    as JsonObject no-undo.

            Assert:NotNullOrEmpty(this-object:InstanceURI).

            /* Build the initial URL, to obtain the tracking flag. */
            assign cRequestURI = substitute("&1&2&3&4",
                                            this-object:InstanceURI, this-object:ManagerURI,
                                            this-object:GetAgentURI, this-object:TrackingObjects).

            /* Replace PAS instance name and specific Agent ID. */
            assign cRequestURI = substitute(cRequestURI, this-object:ApplicationName, pcAgentID).

            /* Make the request to the endpoint and parse results. */
            assign oRequest = this-object:InvokeAPI(cRequestURI).
            if valid-object(oRequest) and oRequest:Has("result") then do:
                /* Return only a true/false value based on value available. */
                assign lSuccess = (logical(oRequest:GetLogical("result")) eq true).
            end. /* Has Result */
        end. /* oemanager */

        /* Report whether tracking is enabled or disabled for this agent ID. */
        oLogger:Info(substitute("Tracking ABLObjects for Agent '&1': &2", pcAgentID, string(lSuccess, "enabled/disabled"))).

        return lSuccess.

        catch err as Progress.Lang.Error:
            oLogger:Error(substitute("Error in TrackingABLObjects: &1", err:GetMessage(1))).
            undo, throw err.
        end catch.
        finally:
            delete object oRequest no-error.
        end finally.
    end method. /* TrackABLObjects */


    method public JsonObject ParseABLObjectReport ( ):
        define variable oAgentObj as JsonObject no-undo.
        define variable oReport   as JsonArray  no-undo.
        define variable oAgent    as JsonObject no-undo.
        define variable cAgentID  as character  no-undo.
        define variable iCount    as integer    no-undo.

        /* Create object for all parsed agents. */
        assign oAgentObj = new JsonObject().

        /* Make request to all agents of this ABLApp. */
        do iCount = 1 to AgentList:Length:
            /* Set request with PAS instance name and specific Agent ID. */
            assign oAgent = AgentList:GetJsonObject(iCount).
            if oAgent:Has("agentId") then
            do on error undo, throw:
                /* Extract the current agent for examination. */
                assign cAgentID = oAgent:GetCharacter("agentId").

                /* Request the ABL objects for this specific agent. */
                if this-object:ParseABLObjectReport(input cAgentID, output oReport) then
                    oAgentObj:Add(cAgentID, oReport). /* Add list to final object. */
            end. /* has agentId */
        end. /* do iCount */

        return oAgentObj.
    end method. /* ParseABLObjectReport */


    method public logical ParseABLObjectReport ( input  piAgentID as integer,
                                                 output poReport  as JsonArray ):
        return this-object:ParseABLObjectReport(string(piAgentID), poReport).
    end method. /* ParseABLObjectReport */


    method public logical ParseABLObjectReport ( input  pcAgentID as character,
                                                 output poReport  as JsonArray ):
        define variable oABLOutput  as JsonObject no-undo.
        define variable oABLObjects as JsonArray  no-undo.
        define variable oObjects    as JsonArray  no-undo.
        define variable oABLObject  as JsonObject no-undo.
        define variable lTracking   as logical    no-undo.
        define variable ix          as integer    no-undo.
        define variable iy          as integer    no-undo.

        Assert:NotNullOrEmpty(pcAgentID).

        /* Confirm if tracking was enabled for this agent. */
        assign lTracking = this-object:TrackingABLObjects(pcAgentID).

        /* Return empty array if not tracking. */
        if not lTracking then return ?.

        /* Create the return array. */
        assign poReport = new JsonArray().

        if this-object:MetricSource eq "oejmx" then
        do on error undo, throw:
            define variable cOutPath as character         no-undo.
            define variable oParser  as ObjectModelParser no-undo.
            define variable oResults as JsonObject        no-undo.

            /* Create the query for tracking objects, and invoke the JMX command. */
            assign cOutPath = this-object:InvokeJMX(this-object:CreateTempQuery("ablobjects", pcAgentID)).

            /* Confirm output file exists, and parse the JSON payload. */
            file-info:file-name = cOutPath.
            if file-info:full-pathname ne ? then do:
                assign oParser = new ObjectModelParser().
                assign oResults = cast(oParser:ParseFile(cOutPath), JsonObject).

                if valid-object(oResults) and oResults:Has("getABLObjectsReport") then
                do on error undo, throw:
                    /* Cannot proceed if there is no result. */
                    if oResults:GetType("getABLObjectsReport") ne JsonDataType:Object then return ?.

                    /* Obtain the necessary payload from the result. */
                    if oResults:GetJsonObject("getABLObjectsReport"):Has("ABLOutput") then
                    do on error undo, throw:
                        assign oABLOutput = oResults:GetJsonObject("getABLObjectsReport"):GetJsonObject("ABLOutput").
                        if valid-object(oABLOutput) and oABLOutput:Has("ABLObjects") and
                           oABLOutput:GetType("ABLObjects") eq JsonDataType:Array then
                            assign oABLObjects = oABLOutput:GetJsonArray("ABLObjects").
                        else
                            assign oABLObjects = ?.

                        if valid-object(oABLObjects) then
                        do ix = 1 to oABLObjects:Length:
                            /* Parse the report payload into a simpler form. */
                            assign oABLObject = oABLObjects:GetJsonObject(ix).
                            if valid-object(oABLObject) and oABLObject:Has("Objects") and
                               oABLObject:GetType("Objects") eq JsonDataType:Array then
                                assign oObjects = oABLObject:GetJsonArray("Objects").
                            else
                                assign oObjects = ?.

                            if valid-object(oObjects) and oObjects:Length gt 0 then
                            do iy = 1 to oObjects:Length:
                                /* Grab the object to add to our full array. */
                                poReport:Add(cast(oObjects:GetJsonObject(iy):Clone(), JsonObject)).
                            end. /* do iy (Objects) */
                        end. /* do ix (ABLObjects) */

                        finally:
                            delete object oABLOutput no-error.
                            delete object oABLObject no-error.
                            delete object oObjects no-error.
                        end finally.
                    end. /* has ABLOutput */
                end. /* has result */
            end. /* File Exists */

            finally:
                delete object oParser no-error.
                delete object oResults no-error.
                os-delete value(cOutPath).
            end finally.
        end. /* oejmx */
        else if this-object:MetricSource eq "oemanager" then do:
            define variable cRequestURI as character  no-undo.
            define variable oRequest    as JsonObject no-undo.

            Assert:NotNullOrEmpty(this-object:InstanceURI).

            /* Build the initial URL, to obtain ABLObjects report. */
            assign cRequestURI = substitute("&1&2&3&4",
                                            this-object:InstanceURI, this-object:ManagerURI,
                                            this-object:GetAgentURI, this-object:GetObjectsReport).

            /* Replace PAS instance name and specific Agent ID. */
            assign cRequestURI = substitute(cRequestURI, this-object:ApplicationName, pcAgentID).

            /* Make the request to the endpoint and parse results. */
            assign oRequest = this-object:InvokeAPI(cRequestURI).
            if valid-object(oRequest) and oRequest:Has("result") then
            do on error undo, throw:
                /* Cannot proceed if there is no result. */
                if oRequest:IsNull("result") then return ?.

                /* Obtain the necessary payload from the result. */
                if oRequest:GetJsonObject("result"):Has("ABLOutput") then
                do on error undo, throw:
                    assign oABLOutput = oRequest:GetJsonObject("result"):GetJsonObject("ABLOutput").
                    if valid-object(oABLOutput) and oABLOutput:Has("ABLObjects") and
                       oABLOutput:GetType("ABLObjects") eq JsonDataType:Array then
                        assign oABLObjects = oABLOutput:GetJsonArray("ABLObjects").
                    else
                        assign oABLObjects = ?.

                    if valid-object(oABLObjects) then
                    do ix = 1 to oABLObjects:Length:
                        /* Parse the report payload into a simpler form. */
                        assign oABLObject = oABLObjects:GetJsonObject(ix).
                        if valid-object(oABLObject) and oABLObject:Has("Objects") and
                           oABLObject:GetType("Objects") eq JsonDataType:Array then
                            assign oObjects = oABLObject:GetJsonArray("Objects").
                        else
                            assign oObjects = ?.

                        if valid-object(oObjects) and oObjects:Length gt 0 then
                        do iy = 1 to oObjects:Length:
                            /* Grab the object to add to our full array. */
                            poReport:Add(cast(oObjects:GetJsonObject(iy):Clone(), JsonObject)).
                        end. /* do iy (Objects) */
                    end. /* do ix (ABLObjects) */

                    finally:
                        delete object oABLOutput no-error.
                        delete object oABLObject no-error.
                        delete object oObjects no-error.
                    end finally.
                end. /* has ABLOutput */

                finally:
                    delete object oRequest no-error.
                end finally.
            end. /* has result */
        end. /* oemanager */

        /* Report how many objects were found within this agent. */
        oLogger:Info(substitute("Total ABLObjects for Agent '&1': &2", pcAgentID, poReport:length)).

        return (poReport:length gt 0).

        catch err as Progress.Lang.Error:
            oLogger:Error(substitute("Error in ParseABLObjectReport: &1", err:GetMessage(1))).
            undo, throw err.
        end catch.
    end method. /* ParseABLObjectReport */

end class.
