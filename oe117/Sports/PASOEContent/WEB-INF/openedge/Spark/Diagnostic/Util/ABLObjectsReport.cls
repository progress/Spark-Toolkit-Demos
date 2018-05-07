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
using OpenEdge.Net.HTTP.Credentials from propath.
using OpenEdge.Net.HTTP.HttpClient from propath.
using OpenEdge.Net.HTTP.IHttpRequest from propath.
using OpenEdge.Net.HTTP.IHttpResponse from propath.
using OpenEdge.Net.HTTP.RequestBuilder from propath.
using OpenEdge.Net.HTTP.IAuthenticatedRequest from propath.

block-level on error undo, throw.

class Spark.Diagnostic.Util.ABLObjectsReport inherits Spark.Diagnostic.Util.Logger use-widget-pool final:

    /*** Static Properties ***/

    define public static property AgentList as JsonArray no-undo get. private set.

    /*** Common Properties ***/

    /* Set automatically as part of the PAS instance startup process. */
    define private property CatalinaBase as character no-undo initial ""
        get():
            if CatalinaBase eq "" then do:
                file-info:filename = trim(os-getenv("CATALINA_BASE")).
                assign CatalinaBase = right-trim(replace(file-info:full-pathname, "~\", "~/"), "~/").
            end.
            return CatalinaBase.
        end get.
        set.

    /* Used as a standard location for creating temporary files. */
    define private property TemporaryDir as character no-undo initial ""
        get():
            if TemporaryDir eq "" then
                assign TemporaryDir = right-trim(replace(session:temp-directory, "~\", "~/"), "~/").
            return TemporaryDir.
        end get.
        set.

    /* Should obtain the Application Name from metrics_setenv.[bat|sh] */
    define private property ApplicationName as character no-undo initial ""
        get():
            if ApplicationName eq "" then do:
                assign ApplicationName = trim(os-getenv("ABLAPP_NAME")).
                oLogger:Debug(substitute("Using ABLApp Name: &1", ApplicationName)).
            end.
            return ApplicationName.
        end get.
        set.

    /* Default to OEJMX which should be available for development and production environments. */
    define private property MetricSource as character no-undo initial "oejmx" get. set.

    /*** OEManager Properties ***/

    /* Should obtain an Instance URI from metrics_setenv.[bat|sh] */
    define private property InstanceURI as character no-undo initial ""
        get():
            if InstanceURI eq "" then do:
                assign InstanceURI = trim(os-getenv("INSTANCE_URI")).
                oLogger:Debug(substitute("Using Instance URI: &1", InstanceURI)).
            end.
            return InstanceURI.
        end get.
        set.

    /* Default used with OEManager. */
    define public property ManagerRealm as character no-undo initial "PASOE Manager Application" get. set.

    /* Default used with OEManager. (Insecure for production use, please change/override!) */
    define public property ManagerUsername as character no-undo initial "tomcat" get. set.

    /* Default used with OEManager. (Insecure for production use, please change/override!) */
    define public property ManagerPassword as character no-undo initial "tomcat" get. set.

    /* Name of the Tomcat WebApp which contains the OEManager application. */
    define private property ManagerURI as character no-undo initial "/oemanager" get. set.

    /* scheme://server:port/oemanager/applications/<app_name>/agents */
    define private property GetAllAgentsURI as character no-undo
        initial "/applications/&1/agents" get. set.

    /* scheme://server:port/oemanager/applications/<app_name>/agents/<agent_id> */
    define private property GetAgentURI as character no-undo
        initial "/applications/&1/agents/&2" get. set.

    /* scheme://server:port/oemanager/applications/<app_name>/agents/<agent_id>/sessions */
    define private property GetAgentSessionURI as character no-undo
        initial "/applications/&1/agents/&2/sessions" get. set.

    /* scheme://server:port/oemanager/applications/<app_name>/agents/trackABLObjects/true */
    define private property TrackObjectsOn as character no-undo
        initial "/trackABLObjects/true" get. set.

    /* scheme://server:port/oemanager/applications/<app_name>/agents/trackABLObjects/false */
    define private property TrackObjectsOff as character no-undo
        initial "/trackABLObjects/false" get. set.

    /* scheme://server:port/oemanager/applications/<app_name>/agents/trackingABLObjects */
    define private property TrackingObjects as character no-undo
        initial "/trackingABLObjects" get. set.

    /* scheme://server:port/oemanager/applications/<app_name>/agents/getABLObjectsReport */
    define private property GetObjectsReport as character no-undo
        initial "/getABLObjectsReport" get. set.

    /* scheme://server:port/oemanager/applications/<app_name>/agents/getABLObjectsReport/sessions/<sess_id> */
    define private property GetSessionObjectsReport as character no-undo
        initial "/getABLObjectsReport/sessions/&1" get. set.

    /*** OEJMX Properties ***/

    /* Binary should reside in CATALINA_BASE/bin/ as a .bat/.sh script. */
    define private property OEJMXBinary as character no-undo initial ""
        get():
            if OEJMXBinary eq "" then
                assign OEJMXBinary = if opsys eq "WIN32" then "oejmx.bat" else "oejmx.sh".
            return OEJMXBinary.
        end get.
        set.

    /* Replace with Application Name in query. */
    define private property AgentsQuery as character no-undo
        initial '~{"O":"PASOE:type=OEManager,name=AgentManager","M":["getAgents","&1"]~}'
        get. set.

    /* Replace with Agent ID (PID) in query. */
    define private property TrackOnQuery as character no-undo
        initial '~{"O":"PASOE:type=OEManager,name=AgentManager","M":["trackABLObjects","&1",true]~}'
        get. set.

    /* Replace with Agent ID (PID) in query. */
    define private property TrackOffQuery as character no-undo
        initial '~{"O":"PASOE:type=OEManager,name=AgentManager","M":["trackABLObjects","&1",false]~}'
        get. set.

    /* Replace with Agent ID (PID) in query. */
    define private property TrackingQuery as character no-undo
        initial '~{"O":"PASOE:type=OEManager,name=AgentManager","M":["trackingABLObjects","&1"]~}'
        get. set.

    /* Replace with Agent ID (PID) in query. */
    define private property ABLObjectsQuery as character no-undo
        initial '~{"O":"PASOE:type=OEManager,name=AgentManager","M":["getABLObjectsReport","&1"]~}'
        get. set.

    /* Replace with Agent ID (PID) and Session ID in query. */
    define private property ABLSessionObjectsQuery as character no-undo
        initial '~{"O":"PASOE:type=OEManager,name=AgentManager","M":["getABLSessionObjectsReport","&1",&2]~}'
        get. set.


    /***** Constructor/Destructor *****/


    constructor public ABLObjectsReport ( input pcSource as character ):
        super().

        /* Set the means of obtaining metrics, or a sane default. */
        case pcSource:
            when "java" or
            when "oejmx" or
            when "jmx" then
                assign this-object:MetricSource = "oejmx".
            when "webapp" or
            when "oemanager" or
            when "oem" then
                assign this-object:MetricSource = "oemanager".
            otherwise
                assign this-object:MetricSource = "oejmx".
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


    method private JsonObject InvokeAPI ( input pcRequestURI as character ):
        /**
         * Use the OEManager webapp to run the necessary queries on the PAS
         * instance. This requires use of the OEHttpClient library to make
         * an API call via REST. For environments where OEManager is not
         * available or desired, use the OEJMX approach.
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


    method private character InvokeJMX ( input pcQueryPath as character ):
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


    method private character CreateTempQuery ( input pcQueryName as character ):
        /* Pass through without an Agent ID. */
        return this-object:CreateTempQuery(pcQueryName, "", 0).
    end method. /* CreateTempQuery */


    method private character CreateTempQuery ( input pcQueryName as character,
                                               input pcAgentID   as character ):
        /* Pass through without an Session ID. */
        return this-object:CreateTempQuery(pcQueryName, pcAgentID, 0).
    end method. /* CreateTempQuery */


    method private character CreateTempQuery ( input pcQueryName as character,
                                               input pcAgentID   as character,
                                               input piSessionID as integer ):
        /**
         * Create a temporary file with the proper OEJMX query to be executed.
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
            when "ablsessionobjects" then
                assign cQueryString = substitute(this-object:ABLSessionObjectsQuery, pcAgentID, piSessionID).
        end case. /* pcQueryName */

        /* Output the modified string to the temporary query file. */
        assign oQuery = cast(oParser:Parse(cQueryString), JsonObject).
        oLogger:Debug(substitute("Writing Query: &1", cQueryPath)).
        oQuery:WriteFile(cQueryPath). /* Send JSON data to disk. */

        return cQueryPath. /* Path to temporary query file. */

        finally:
            delete object oParser no-error.
            delete object oQuery no-error.
        end finally.
    end method. /* CreateTempQuery */


    method private JsonArray FilterABLObjects ( input poObjData as JsonObject,
                                                input pcExclude as character ):
        /**
         * Regardless of how the ABLObjectsReport is obtained, the results from
         * both OEManager and OEJMX should result in the same array of data after
         * filtering the original object. To simplify this process, this method
         * should take the results of either form of query and produce a single
         * array of objects based on the exclusion list provided.
         */

        define variable oReport     as JsonArray  no-undo.
        define variable oABLObjects as JsonArray  no-undo.
        define variable oObjects    as JsonArray  no-undo.
        define variable oABLObject  as JsonObject no-undo.
        define variable cObjName    as character  no-undo.
        define variable cObjSource  as character  no-undo.
        define variable lTracking   as logical    no-undo.
        define variable lMatches    as logical    no-undo.
        define variable ix          as integer    no-undo.
        define variable iy          as integer    no-undo.
        define variable iz          as integer    no-undo.

        /* Create the return array. */
        assign oReport = new JsonArray().

        /* Continue parsing the output of the report. */
        if valid-object(poObjData) and poObjData:Has("ABLObjects") and
           poObjData:GetType("ABLObjects") eq JsonDataType:Array then
            assign oABLObjects = poObjData:GetJsonArray("ABLObjects").
        else
            assign oABLObjects = ?.

        /* Begin cycling through the ABL Object entries. */
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
                if pcExclude eq "" then do:
                    /* If not excluding specific names, clone the object to the array. */
                    oReport:Add(cast(oObjects:GetJsonObject(iy):Clone(), JsonObject)).
                end.
                else if not oObjects:GetJsonObject(iy):Has("Name") then do:
                    /* Extract some values for comparison when filtering the results. */
                    assign
                        cObjSource = oObjects:GetJsonObject(iy):GetCharacter("Source")
                        lMatches   = false
                        .

                    do iz = 1 to num-entries(pcExclude):
                        if cObjSource matches entry(iz, pcExclude) then
                        assign lMatches = true. /* Remember if match found. */
                    end. /* do iz */

                    /* Retain only objects which DO NOT match the exclusion list. */
                    if not lMatches then
                        oReport:Add(cast(oObjects:GetJsonObject(iy):Clone(), JsonObject)).
                end.
                else do:
                    /* Extract some values for comparison when filtering the results. */
                    assign
                        cObjName   = oObjects:GetJsonObject(iy):GetCharacter("Name")
                        cObjSource = oObjects:GetJsonObject(iy):GetCharacter("Source")
                        lMatches   = false
                        .

                    /* Determine if the current object matches the exclusion list. */
                    do iz = 1 to num-entries(pcExclude):
                        if cObjName matches entry(iz, pcExclude) or
                           cObjSource matches entry(iz, pcExclude) then
                        assign lMatches = true. /* Remember if match found. */
                    end. /* do iz */

                    /* Retain only objects which DO NOT match the exclusion list. */
                    if not lMatches then
                        oReport:Add(cast(oObjects:GetJsonObject(iy):Clone(), JsonObject)).
                end. /* do (Has Name) */
            end. /* do iy (Objects) */
        end. /* do ix (ABLObjects) */

        return oReport.

        catch err as Progress.Lang.Error:
            oLogger:Error(substitute("Error in FilterABLObjects: &1", err:GetMessage(1))).
            undo, throw err.
        end catch.
        finally:
            delete object oABLObject no-error.
            delete object oObjects no-error.
        end finally.
    end method. /* FilterABLObjects */


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
                os-delete value(cOutPath).
                delete object oParser no-error.
                delete object oResults no-error.
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
        if valid-object(AgentList) then
            oLogger:Debug(substitute("Available Agents: &1", AgentList:GetJsonText())).

        catch err as Progress.Lang.Error:
            oLogger:Error(substitute("Error in GetAgents: &1", err:GetMessage(1))).
            undo, throw err.
        end catch.
    end method. /* GetAgents */


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
                os-delete value(cOutPath).
                delete object oParser no-error.
                delete object oResults no-error.
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
            oLogger:Error(substitute("Error in TrackABLObjects: &1", err:GetMessage(1))).
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
                os-delete value(cOutPath).
                delete object oParser no-error.
                delete object oResults no-error.
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


    method public logical ParseABLObjectReport ( input  piAgentID as integer,
                                                 input  pcExclude as character,
                                                 output poReport  as JsonArray ):
        /* Allow initial passing of Agent ID as an integer. */
        return this-object:ParseABLObjectReport(string(piAgentID), pcExclude, poReport).
    end method. /* ParseABLObjectReport */


    method public logical ParseABLObjectReport ( input  pcAgentID as character,
                                                 input  pcExclude as character,
                                                 output poReport  as JsonArray ):
        define variable oABLOutput as JsonObject no-undo.

        Assert:NotNullOrEmpty(pcAgentID).

        /* Leave a quick note about what is being built, and with any exceptions. */
        oLogger:Debug(substitute("Reporting ABLObjects for Agent '&1', excluding: &2", pcAgentID, pcExclude)).

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
                        assign oABLOutput = oResults:GetJsonObject("getABLObjectsReport"):GetJsonObject("ABLOutput").
                end. /* has result */
            end. /* File Exists */

            finally:
                os-delete value(cOutPath).
                delete object oParser no-error.
                delete object oResults no-error.
            end finally.
        end. /* oejmx */
        else if this-object:MetricSource eq "oemanager" then
        do on error undo, throw:
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
            if valid-object(oRequest) and oRequest:Has("result") then do:
                /* Cannot proceed if there is no result. */
                if oRequest:IsNull("result") then return ?.

                /* Obtain the necessary payload from the result. */
                if oRequest:GetJsonObject("result"):Has("ABLOutput") then
                    assign oABLOutput = oRequest:GetJsonObject("result"):GetJsonObject("ABLOutput").
            end. /* has result */

            finally:
                delete object oRequest no-error.
            end finally.
        end. /* oemanager */

        /* Filter the results based on the exclusion list. */
        assign poReport = this-object:FilterABLObjects(oABLOutput, pcExclude).

        /* Report how many objects were found within this agent. */
        oLogger:Info(substitute("Total ABLObjects for Agent '&1': &2", pcAgentID, poReport:length)).

        return (poReport:length gt 0).

        catch err as Progress.Lang.Error:
            oLogger:Error(substitute("Error in ParseABLObjectReport: &1", err:GetMessage(1))).
            undo, throw err.
        end catch.
        finally:
            delete object oABLOutput no-error.
        end finally.
    end method. /* ParseABLObjectReport */

    method public logical ParseSessionABLObjectReport ( input  piAgentID   as integer,
                                                        input  piSessionID as integer,
                                                        input  pcExclude   as character,
                                                        output poReport    as JsonArray ):
        /* Allows passing of Agent ID as an integer. */
        return this-object:ParseSessionABLObjectReport(string(piAgentID), piSessionID, pcExclude, poReport).
    end method. /* ParseSessionABLObjectReport */


    method public logical ParseSessionABLObjectReport ( input  pcAgentID   as character,
                                                        input  piSessionID as integer,
                                                        input  pcExclude   as character,
                                                        output poReport    as JsonArray ):
        define variable oABLOutput as JsonObject no-undo.

        Assert:NotNullOrEmpty(pcAgentID).
        Assert:NonZero(piSessionID).

        /* Leave a quick note about what is being built, and with any exceptions. */
        oLogger:Debug(substitute("Reporting ABLObjects for Agent '&1'/Session '&2', excluding: &3",
                                 pcAgentID, piSessionID, pcExclude)).

        if this-object:MetricSource eq "oejmx" then
        do on error undo, throw:
            define variable cOutPath as character         no-undo.
            define variable oParser  as ObjectModelParser no-undo.
            define variable oResults as JsonObject        no-undo.

            /* Create the query for tracking objects, and invoke the JMX command. */
            assign cOutPath = this-object:InvokeJMX(this-object:CreateTempQuery("ablsessionobjects",
                                                                                pcAgentID, piSessionID)).

            /* Confirm output file exists, and parse the JSON payload. */
            file-info:file-name = cOutPath.
            if file-info:full-pathname ne ? then do:
                assign oParser = new ObjectModelParser().
                assign oResults = cast(oParser:ParseFile(cOutPath), JsonObject).

                if valid-object(oResults) and oResults:Has("getABLSessionObjectsReport") then
                do on error undo, throw:
                    /* Cannot proceed if there is no result. */
                    if oResults:GetType("getABLSessionObjectsReport") ne JsonDataType:Object then return ?.

                    /* Obtain the necessary payload from the result. */
                    if oResults:GetJsonObject("getABLSessionObjectsReport"):Has("ABLOutput") then
                        assign oABLOutput = oResults:GetJsonObject("getABLSessionObjectsReport"):GetJsonObject("ABLOutput").
                end. /* has result */
            end. /* File Exists */

            finally:
                os-delete value(cOutPath).
                delete object oParser no-error.
                delete object oResults no-error.
            end finally.
        end. /* oejmx */
        else if this-object:MetricSource eq "oemanager" then
        do on error undo, throw:
            define variable cRequestURI as character  no-undo.
            define variable oRequest    as JsonObject no-undo.

            Assert:NotNullOrEmpty(this-object:InstanceURI).

            /* Build the initial URL, to obtain ABLObjects report. */
            assign cRequestURI = substitute("&1&2&3&4",
                                            this-object:InstanceURI, this-object:ManagerURI,
                                            this-object:GetAgentURI, this-object:GetSessionObjectsReport).

            /* Replace PAS instance name and specific Agent ID. */
            assign cRequestURI = substitute(cRequestURI, this-object:ApplicationName, pcAgentID).

            /* Make the request to the endpoint and parse results. */
            assign oRequest = this-object:InvokeAPI(cRequestURI).
            if valid-object(oRequest) and oRequest:Has("result") then do:
                /* Cannot proceed if there is no result. */
                if oRequest:IsNull("result") then return ?.

                /* Obtain the necessary payload from the result. */
                if oRequest:GetJsonObject("result"):Has("ABLOutput") then
                    assign oABLOutput = oRequest:GetJsonObject("result"):GetJsonObject("ABLOutput").
            end. /* has result */

            finally:
                delete object oRequest no-error.
            end finally.
        end. /* oemanager */

        /* Filter the results based on the exclusion list. */
        assign poReport = this-object:FilterABLObjects(oABLOutput, pcExclude).

        /* Report how many objects were found within this agent. */
        oLogger:Info(substitute("Total ABLObjects for Agent '&1', Session '&2': &3",
                                pcAgentID, piSessionID, poReport:length)).

        return (poReport:length gt 0).

        catch err as Progress.Lang.Error:
            oLogger:Error(substitute("Error in ParseSessionABLObjectReport: &1", err:GetMessage(1))).
            undo, throw err.
        end catch.
        finally:
            delete object oABLOutput no-error.
        end finally.
    end method. /* ParseSessionABLObjectReport */

end class.
