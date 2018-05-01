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

class Spark.Core.Util.ABLObjectsReport inherits Spark.Core.Util.Logger use-widget-pool:

    define public property MetricSource as character no-undo initial "oemanager"
        get. private set.

    define public property ManagerRealm as character no-undo initial "PASOE Manager Application"
        get. set.

    define public property ManagerUsername as character no-undo initial "tomcat"
        get. set.

    define public property ManagerPassword as character no-undo initial "tomcat"
        get. set.

    define protected property ManagerURI as character no-undo initial "/oemanager"
        get. private set.

    define protected property GetApplicationsURI as character no-undo initial "/applications"
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

    define protected property JMXQueriesDir as character no-undo initial "jmxqueries"
        get. private set.

    define public static property OEJMXBinary as character no-undo initial ""
        get():
            if OEJMXBinary eq "" then
                assign OEJMXBinary = if opsys eq "WIN32" then "oejmx.bat" else "oejmx.sh".
            return OEJMXBinary.
        end get.
        private set.

    define public static property CatalinaBase as character no-undo initial ""
        get():
            if CatalinaBase eq "" then do:
                file-info:filename = trim(os-getenv("CATALINA_BASE")).
                assign CatalinaBase = right-trim(replace(file-info:full-pathname, "~\", "~/"), "~/").
            end.
            return CatalinaBase.
        end get.
        private set.

    define public static property ApplicationName as character no-undo initial ""
        get():
            if ApplicationName eq "" then
                assign ApplicationName = trim(os-getenv("ABLAPP_NAME")).
            return ApplicationName.
        end get.
        private set.

    define public static property InstanceURI as character no-undo initial ""
        get():
            if InstanceURI eq "" then
                assign InstanceURI = trim(os-getenv("INSTANCE_URI")).
            return InstanceURI.
        end get.
        private set.

    define public static property AgentList as JsonArray no-undo
        get():
            if not valid-object(AgentList) then
                AgentList = new JsonArray().
            return AgentList.
        end get.
        protected set.


    constructor ABLObjectsReport ( ):
        super().

        /* Make sure a default source has been set. */
        assign this-object:MetricSource = "oemanager".
        this-object:CheckTempPath().
    end constructor.


    constructor ABLObjectsReport ( input pcSource as character ):
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
        define variable cTempPath as character no-undo.

        /* Make sure we have a consistent path for temporary files. */
        assign cTempPath = substitute("&1/temp", CatalinaBase).
        os-create-dir value(cTempPath).
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

        oLogger:Info(substitute("Requesting URL: &1", pcRequestURI)).

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


    method protected JsonObject InvokeJMX ( input pcQueryName as character ):
        /**
         * Make a query again the running Java process via JMX to obtain any
         * information or set flags to control monitoring/debugging options.
         *   The -R flag removes the header, leaving only the JSON body.
         *   The -Q flag specifies the name of the query to be executed.
         *   The -O flag sets a specific location for the query output.
         * Example:
         *   oejmx.[bat|sh] -R -Q jmxqueries/<name>.qry -O ../temp/<output>.json
         */
        define variable cBinaryPath as character no-undo.
        define variable cOutputPath as character no-undo.
        define variable cCommand    as character no-undo.
        define variable iTime       as integer   no-undo.

        /* Cannot proceed if the requested query is not on the list of expected items. */
        if not can-do("agents,trackon,tracking,ablobjects,trackoff", pcQueryName) then return ?.

        assign iTime = mtime. /* Each request should be timestamped. */
        assign cBinaryPath = substitute("&1/bin/&2", CatalinaBase, OEJMXBinary).
        assign cOutputPath = substitute("&1/temp/jmx_&2_&3.json", CatalinaBase, pcQueryName, iTime).
        assign cCommand = substitute("&1 -R -Q jmxqueries/&2.qry -O &3",
                                     cBinaryPath, pcQueryName, cOutputPath).

        oLogger:Info(substitute("Running Command: &1", cCommand)).
        os-command silent no-console value(cCommand).
        oLogger:Info("Command Finished").

    end method. /* InvokeJMX */


    /***** Public Methods *****/


    method public void GetAgents ( ):
        define variable cRequestURI as character  no-undo.
        define variable oRequest    as JsonObject no-undo.

        if this-object:MetricSource eq "oejmx" then do:
            this-object:InvokeJMX("agents").
        end. /* jmx */

        if this-object:MetricSource eq "oemanager" then do:
            Assert:NotNullOrEmpty(InstanceURI).

            /* Request a list of agents from the OEManager webapp. */
            assign cRequestURI = substitute("&1&2&3",
                                            InstanceURI, this-object:ManagerURI,
                                            this-object:GetAllAgentsURI).

            /* Set request with PAS instance name. */
            assign cRequestURI = substitute(cRequestURI, ApplicationName).

            /* Make the request to the endpoint and parse results. */
            assign oRequest = this-object:InvokeAPI(cRequestURI).
            if valid-object(oRequest) and oRequest:Has("result") then do:
                if oRequest:GetJsonObject("result"):Has("agents") then
                    AgentList = oRequest:GetJsonObject("result"):GetJsonArray("agents").
            end. /* Has Result */

            /* Log output results of request. */
            oLogger:Info(substitute("Agents: &1", AgentList:GetJsonText())).
        end. /* oemanager */

        catch err as Progress.Lang.Error:
            oLogger:Error(substitute("Error in GetAgents: &1", err:GetMessage(1))).
            undo, throw err.
        end catch.
        finally:
            delete object oRequest no-error.
        end finally.
    end method. /* GetAgents */


    method public logical TrackABLObjects ( input plEnable as logical ):
        define variable cRequestURI as character  no-undo.
        define variable cAgentID    as character  no-undo.
        define variable oAgent      as JsonObject no-undo.
        define variable oRequest    as JsonObject no-undo.
        define variable iCount      as integer    no-undo.

        if this-object:MetricSource eq "oejmx" then do:
        end. /* jmx */

        if this-object:MetricSource eq "oemanager" then do:
            Assert:NotNullOrEmpty(InstanceURI).

            /* Make request to all agents of this ABLApp. */
            do iCount = 1 to AgentList:Length:
                /* Set request with PAS instance name and specific Agent ID. */
                assign oAgent = AgentList:GetJsonObject(iCount).
                if oAgent:Has("agentId") then do:
                    /* Set the base URL to get information for a specific agent. */
                    assign cRequestURI = substitute("&1&2&3",
                                                    InstanceURI, this-object:ManagerURI,
                                                    this-object:GetAgentURI).

                    /* Build the initial URL, to prepare to set the tracking flag. */
                    assign cAgentID = oAgent:GetCharacter("agentId").
                    assign cRequestURI = substitute(cRequestURI, ApplicationName, cAgentID).
                    if plEnable then
                        /* Turn tracking on. */
                        assign cRequestURI = substitute("&1&2",
                                                        cRequestURI, this-object:TrackObjectsOn).
                    else
                        /* Turn tracking off. */
                        assign cRequestURI = substitute("&1&2",
                                                        cRequestURI, this-object:TrackObjectsOff).

                    /* Make the request to the endpoint and parse results. */
                    assign oRequest = this-object:InvokeAPI(cRequestURI).
                    if valid-object(oRequest) and oRequest:Has("result") then do:
                        if not oRequest:IsNull("result") then do:
                            /* Report the result of the previous request. */
                            oLogger:Info(substitute("trackABLObjects: &1 = &2",
                                                    trim(string(plEnable, "enabled/disabled")),
                                                    oRequest:GetLogical("result"))).

                            /* Confirm tracking was enabled/disabled. */
                            oLogger:Info(substitute("Tracking State: &1", string(this-object:trackingABLObjects(cAgentID)), "tracking/disabled")).

                            /* Return the value from the original tracking request. */
                            return (oRequest:GetLogical("result") eq true).
                        end. /* result not null */
                    end. /* Has Result */
                end. /* has agentId */
            end. /* do iCount */
        end. /* oemanager */

        return false.

        catch err as Progress.Lang.Error:
            oLogger:Error(substitute("Error in trackABLObjects: &1", err:GetMessage(1))).
            undo, throw err.
        end catch.
        finally:
            delete object oRequest no-error.
        end finally.
    end method. /* TrackABLObjects */


    method public logical TrackingABLObjects ( input pcAgentID as character ):
        define variable cRequestURI as character  no-undo.
        define variable oRequest    as JsonObject no-undo.

        Assert:NotNullOrEmpty(pcAgentID).

        if this-object:MetricSource eq "oejmx" then do:
        end. /* jmx */

        if this-object:MetricSource eq "oemanager" then do:
            /* Build the initial URL, to obtain the tracking flag. */
            assign cRequestURI = substitute("&1&2&3&4",
                                            InstanceURI, this-object:ManagerURI,
                                            this-object:GetAgentURI, this-object:TrackingObjects).

            /* Replace PAS instance name and specific Agent ID. */
            assign cRequestURI = substitute(cRequestURI, ApplicationName, pcAgentID).

            /* Make the request to the endpoint and parse results. */
            assign oRequest = this-object:InvokeAPI(cRequestURI).
            if valid-object(oRequest) and oRequest:Has("result") then do:
                /* Return only a true/false value based on value available. */
                return (logical(oRequest:GetLogical("result")) eq true).
            end. /* Has Result */
        end. /* oemanager */

        return ?. /* Return unknown if no result property available. */

        catch err as Progress.Lang.Error:
            oLogger:Error(substitute("Error in TrackingABLObjects: &1", err:GetMessage(1))).
            undo, throw err.
        end catch.
        finally:
            delete object oRequest no-error.
        end finally.
    end method. /* TrackABLObjects */


    method public JsonObject ParseABLObjectReport ( ):
        define variable cRequestURI as character  no-undo.
        define variable cAgentID    as character  no-undo.
        define variable oAgent      as JsonObject no-undo.
        define variable oRequest    as JsonObject no-undo.
        define variable oEntry      as JsonObject no-undo.
        define variable oABLOutput  as JsonObject no-undo.
        define variable oABLObjects as JsonArray  no-undo.
        define variable oObjects    as JsonArray  no-undo.
        define variable oABLObject  as JsonObject no-undo.
        define variable oParsed     as JsonArray  no-undo.
        define variable oAgentObj   as JsonObject no-undo.
        define variable iTotalObj   as integer    no-undo.
        define variable iCount      as integer    no-undo.
        define variable ix          as integer    no-undo.
        define variable iy          as integer    no-undo.

        /* Create object for all parsed agents. */
        assign oAgentObj = new JsonObject().

        if this-object:MetricSource eq "oejmx" then do:
        end. /* jmx */

        if this-object:MetricSource eq "oemanager" then do:
            Assert:NotNullOrEmpty(InstanceURI).

            /* Make request to all agents of this ABLApp. */
            do iCount = 1 to AgentList:Length:
                /* Set request with PAS instance name and specific Agent ID. */
                assign oAgent = AgentList:GetJsonObject(iCount).
                if oAgent:Has("agentId") then do:
                    /* Extract the current agent for examination. */
                    assign cAgentID = oAgent:GetCharacter("agentId").

                    /* Create array of parsed entries for this agent. */
                    assign oParsed = new JsonArray().

                    /* Build the initial URL, to obtain ABLObjects report. */
                    assign cRequestURI = substitute("&1&2&3&4",
                                                    InstanceURI, this-object:ManagerURI,
                                                    this-object:GetAgentURI, this-object:GetObjectsReport).

                    /* Replace PAS instance name and specific Agent ID. */
                    assign cRequestURI = substitute(cRequestURI, ApplicationName, cAgentID).

                    /* Make the request to the endpoint and parse results. */
                    assign oRequest = this-object:InvokeAPI(cRequestURI).
                    if valid-object(oRequest) and oRequest:Has("result") then
                    do on error undo, throw:
                        /* Cannot proceed if there is no result. */
                        if oRequest:IsNull("result") then return oAgentObj.

                        /* Obtain the necessary payload from the result. */
                        if oRequest:GetJsonObject("result"):Has("ABLOutput") then
                        do on error undo, throw:
                            assign oABLOutput = oRequest:GetJsonObject("result"):GetJsonObject("ABLOutput").
                            if oABLOutput:Has("ABLObjects") then
                                assign oABLObjects = oABLOutput:GetJsonArray("ABLObjects").
                            else
                                assign oABLObjects = ?.

                            if valid-object(oABLObjects) then
                            do ix = 1 to oABLObjects:Length:
                                /* Parse the report payload into a simpler form. */
                                assign oABLObject = oABLObjects:GetJsonObject(ix).
                                assign oObjects = oABLObject:GetJsonArray("Objects").

                                if valid-object(oObjects) and oObjects:Length gt 0 then
                                do iy = 1 to oObjects:Length:
                                    /* Grab the object to add to our full array. */
                                    oParsed:Add(cast(oObjects:GetJsonObject(iy):Clone(), JsonObject)).
                                end. /* do iy (Objects) */
                            end. /* do ix (ABLObjects) */

                            assign iTotalObj = iTotalObj + oParsed:length.

                            finally:
                                delete object oABLOutput no-error.
                                delete object oABLObject no-error.
                                delete object oObjects no-error.
                            end finally.
                        end. /* has ABLOutput */
                    end. /* has result */

                    /* Add list of objects, by agent ID, to a final object. */
                    oAgentObj:Add(cAgentID, oParsed).
                end. /* has agentId */
            end. /* do iCount */

            oLogger:Info(substitute("Total ABLObjects for &1 Agent(s): &2", AgentList:Length, iTotalObj)).
        end. /* oemanager */

        return oAgentObj.

        catch err as Progress.Lang.Error:
            oLogger:Error(substitute("Error in ParseABLObjectReport: &1", err:GetMessage(1))).
            undo, throw err.
        end catch.
        finally:
            delete object oRequest no-error.
        end finally.
    end method. /* ParseABLObjectReport */

end class.
