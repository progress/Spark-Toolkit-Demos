/*------------------------------------------------------------------------
   File        : ABLObjectsReport
   Purpose     :
   Description :
   Author(s)   : Irfan Syed (isyed@progress.com>)
   Created     : Tue Nov 28 14:07:12 EST 2017
   Notes       :
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

    define protected property ApplicationName as character no-undo
        get():
            return trim(os-getenv("ABLAPP_NAME")).
        end get.
        private set.

    define protected property InstanceURI as character no-undo
        get():
            return trim(os-getenv("INSTANCE_URI")).
        end get.
        private set.

    define protected property AgentList as JsonArray no-undo
        get():
            if not valid-object(AgentList) then
                AgentList = new JsonArray().
            return AgentList.
        end get.
        private set.


    /***** Protected Methods *****/


    method protected JsonObject InvokeAPI ( input pcRequestURI as character ):
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
            return new JsonObject(). /* Return an empty object. */
        end. /* Response not HTTP/200 */

        /* @TODO: Add more logic to ensure entity is a JSON body prior to casting blindly. */
        return cast(oHttpResp:Entity, JsonObject).

        catch err as Progress.Lang.Error:
            oLogger:Error(substitute("Failed while invoking ", pcRequestURI)).
            oLogger:Error(substitute("Failed in InvokeAPI ", err:GetMessage(1))).
            return new JsonObject(). /* Fail with an empty object. */
        end catch.
        finally:
            delete object oCredentials no-error.
            delete object oHttpReq no-error.
            delete object oHttpResp no-error.
        end finally.
    end method. /* InvokeAPI */


    /***** Public Methods *****/


    method public void GetAgents ( ):
        define variable cRequestURI as character  no-undo.
        define variable oRequest    as JsonObject no-undo.

        Assert:NotNullOrEmpty(this-object:InstanceURI).

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
                this-object:AgentList = oRequest:GetJsonObject("result"):GetJsonArray("agents").
        end. /* Has Result */

        /* Log output results of request. */
        oLogger:Info(substitute("Agents: &1", this-object:AgentList:GetJsonText())).

        catch err as Progress.Lang.Error:
            oLogger:Error(substitute("Error in GetAgents: &1", err:GetMessage(1))).
            undo, throw err.
        end catch.
        finally:
            delete object oRequest no-error.
        end finally.
    end method. /* GetAgents */


    method public void TrackABLObjects ( input plEnable as logical ):
        define variable cRequestURI as character  no-undo.
        define variable cAgentID    as character  no-undo.
        define variable oAgent      as JsonObject no-undo.
        define variable oRequest    as JsonObject no-undo.
        define variable iCount      as integer    no-undo.

        /* Make request to all agents of this ABLApp. */
        do iCount = 1 to this-object:AgentList:Length:
            /* Set request with PAS instance name and specific Agent ID. */
            assign oAgent = this-object:AgentList:GetJsonObject(iCount).
            if oAgent:Has("agentId") then do:
                /* Set the base URL to get information for a specific agent. */
                assign cRequestURI = substitute("&1&2&3",
                                                this-object:InstanceURI, this-object:ManagerURI,
                                                this-object:GetAgentURI).

                /* Build the initial URL, to prepare to set the tracking flag. */
                assign cAgentID = oAgent:GetCharacter("agentId").
                assign cRequestURI = substitute(cRequestURI, this-object:ApplicationName, cAgentID).
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
                    if not oRequest:IsNull("result") then /* Confirm tracking is enabled/disabled. */
                        oLogger:Info(substitute("Tracking State: &1", this-object:trackingABLObjects(cAgentID))).
                end. /* Has Result */
            end. /* has agentId */
        end. /* do iCount */

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
            return (logical(oRequest:GetLogical("result")) eq true).
        end. /* Has Result */

        return ?. /* Return unknown if no result property available. */

        catch err as Progress.Lang.Error:
            oLogger:Error(substitute("Error in TrackingABLObjects: &1", err:GetMessage(1))).
            undo, throw err.
        end catch.
        finally:
            delete object oRequest no-error.
        end finally.
    end method. /* TrackABLObjects */


    method public void ParseABLObjectReport ( ):
        define variable cRequestURI as character  no-undo.
        define variable cAgentID    as character  no-undo.
        define variable oAgent      as JsonObject no-undo.
        define variable oRequest    as JsonObject no-undo.
        define variable oEntry      as JsonObject no-undo.
        define variable oABLOutput  as JsonObject no-undo.
        define variable oABLObjects as JsonArray  no-undo.
        define variable oParsed     as JsonArray  no-undo.
        define variable oABLObject  as JsonObject no-undo.
        define variable oAgentObj   as JsonObject no-undo.
        define variable iCount      as integer    no-undo.
        define variable ix          as integer    no-undo.
        define variable iy          as integer    no-undo.

        /* Create object for all parsed agents. */
        assign oAgentObj = new JsonObject().

        /* Make request to all agents of this ABLApp. */
        do iCount = 1 to this-object:AgentList:Length:
            /* Set request with PAS instance name and specific Agent ID. */
            assign oAgent = this-object:AgentList:GetJsonObject(iCount).
            if oAgent:Has("agentId") then do:
                assign cAgentID = oAgent:GetCharacter("agentId").

                /* Create array of parsed entries for this agent. */
                assign oParsed = new JsonArray().

                /* Build the initial URL, to obtain ABLObjects report. */
                assign cRequestURI = substitute("&1&2&3&4",
                                                this-object:InstanceURI, this-object:ManagerURI,
                                                this-object:GetAgentURI, this-object:GetObjectsReport).

                /* Replace PAS instance name and specific Agent ID. */
                assign cRequestURI = substitute(cRequestURI, this-object:ApplicationName, cAgentID).

                /* Make the request to the endpoint and parse results. */
                assign oRequest = this-object:InvokeAPI(cRequestURI).
                if valid-object(oRequest) and oRequest:Has("result") then do:
                    /* Cannot proceed if there is no result. */
                    if oRequest:IsNull("result") then return.

                    /* Dump the full response for debugging of the debugging. */
                    oLogger:Trace("Parsed JsonObject is as below").
                    oLogger:Trace(string(oRequest:GetJsonText())).

                    /* Obtain the necessary payload from the result. */
                    assign oABLOutput = oRequest:GetJsonObject("result"):GetJsonObject("ABLOutput").
                    assign oABLObjects = oABLOutput:GetJsonArray("ABLObjects").

                    do while ix le oABLObjects:Length:
                        /* Parse the report payload into a simpler form. */
                        assign oABLObject = oABLObjects:GetJsonObject(ix).
                        if oABLObject:GetJsonArray("Objects"):Length gt 0 then do:

                            do while iy le oABLObject:GetJsonArray("Objects"):Length:
                                /* Iterate over the available objects, if any. */
                                oEntry = new JsonObject().

                                if oABLObject:GetJsonArray("Objects"):GetJsonObject(iy):Has("ObjType") then
                                    oEntry:Add("ObjType", oABLObject:GetJsonArray("Objects")
                                                                    :GetJsonObject(iy):GetCharacter("ObjType")).
                                else do:
                                    oLogger:Error("ObjType not available in the payload").
                                    oLogger:Error(string(oABLObject:GetJsonArray("Objects")
                                                                   :GetJsonObject(iy):GetJsonText())).
                                end.

                                if oABLObject:GetJsonArray("Objects"):GetJsonObject(iy):Has("Source") then
                                    oEntry:Add("Source", oABLObject:GetJsonArray("Objects")
                                                                   :GetJsonObject(iy):GetCharacter("Source")).
                                else do:
                                    oLogger:Error("ObjType not available in the payload").
                                    oLogger:Error(string(oABLObject:GetJsonArray("Objects")
                                                                   :GetJsonObject(iy):GetJsonText())).
                                end.

                                if oABLObject:GetJsonArray("Objects"):GetJsonObject(iy):Has("Line") then
                                    oEntry:Add("Line", oABLObject:GetJsonArray("Objects")
                                                                 :GetJsonObject(iy):GetInteger("Line")).
                                else do:
                                    oLogger:Error("Line not available in the payload").
                                    oLogger:Error(string(oABLObject:GetJsonArray("Objects")
                                                                   :GetJsonObject(iy):GetJsonText())).
                                end.

                                oParsed:Add(oEntry).
                                assign iy = iy + 1.
                            end. /* do while iy */

                        end. /* length gt 0 */

                        assign ix = ix + 1.
                    end. /* do while ix */
                end. /* has response */

                /* Add list of objects, by agent ID, to a final object. */
                oAgentObj:Add(cAgentID, oParsed).
            end. /* has agentId */
        end. /* do iCount */

        oLogger:Info(substitute("Total objects found: &1", oParsed:Length)).
        oLogger:Info("Parsed output from ABLObjects report:").
        oLogger:Info(string(oParsed:GetJsonText())).

        catch err as Progress.Lang.Error:
            oLogger:Error(substitute("Error in ParseABLObjectReport: &1", err:GetMessage(1))).
            undo, throw err.
        end catch.
        finally:
            delete object oRequest no-error.
        end finally.
    end method. /* ParseABLObjectReport */

end class.
