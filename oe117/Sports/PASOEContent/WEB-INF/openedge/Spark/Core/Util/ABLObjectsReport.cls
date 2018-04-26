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

    define protected property ManagerRealm as character no-undo initial "PASOE Manager Application"
        get. private set.

    define protected property ManagerUsername as character no-undo initial "tomcat"
        get. private set.

    define protected property ManagerPassword as character no-undo initial "tomcat"
        get. private set.

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

        Assert:NotNullOrEmpty(pcRequestURI).
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
            oLogger:Error("Response Code was not HTTP/200").
            oLogger:Error(string(oHttpResp:StatusCode)).
            return error.
        end. /* Not 200 */

        return cast(oHttpResp:Entity, JsonObject).

        catch err as Progress.Lang.Error:
            oLogger:Error(substitute("Failed while invoking ", pcRequestURI)).
            oLogger:Error(substitute("Failed in InvokeAPI ", err:GetMessage(1))).
            return error "Error in InvokeAPI".
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
                                        this-object:InstanceURI, this-object:ManagerURI, this-object:GetAllAgentsURI).
        assign cRequestURI = substitute(cRequestURI, this-object:ApplicationName). /* Set request with PAS instance name. */

        /* Make the request to the endpoint. */
        assign oRequest = cast(this-object:InvokeAPI(cRequestURI), JsonObject).

        if oRequest:Has("result") then do:
            if oRequest:GetJsonObject("result"):Has("agents") then
                this-object:AgentList = oRequest:GetJsonObject("result"):GetJsonArray("agents").
        end. /* Has Result */

        oLogger:Info(string(this-object:AgentList:GetJsonText())).

        catch e as Progress.Lang.Error :
            oLogger:Error("Error in GetAgents").
            oLogger:Error(e:GetMessage(1)).
            return error "Error in GetAgents".
        end catch.

        finally:
            delete object oRequest.
        end finally.
    end method. /* GetAgents */


    method public void trackABLObjects ( input plEnable as logical ):
        define variable cRequestURI as character  no-undo.
        define variable oAgent      as JsonObject no-undo.
        define variable oRequest    as JsonObject no-undo.
        define variable iCount      as integer    no-undo.

        assign cRequestURI = substitute("&1&2&3",
                                        this-object:InstanceURI, this-object:ManagerURI, this-object:GetAgentURI).

        do iCount = 1 to this-object:AgentList:Length:
            /* Set request with PAS instance name and specific Agent ID. */
            assign oAgent = this-object:AgentList:GetJsonObject(iCount).
            if oAgent:Has("agentId") then do:
                /* Build the initial URL, to prepare to set the tracking flag. */
                assign cRequestURI = substitute(cRequestURI,
                                                this-object:ApplicationName, oAgent:GetCharacter("agentId")).
                if plEnable then
                    /* Turn tracking on. */
                    assign cRequestURI = substitute("&1&2",
                                                    cRequestURI, this-object:TrackObjectsOn).
                else
                    /* Turn tracking off. */
                    assign cRequestURI = substitute("&1&2",
                                                    cRequestURI, this-object:TrackObjectsOff).

                /* Make the request to the endpoint. */
                assign oRequest = cast(this-object:InvokeAPI(cRequestURI), JsonObject).

                if oRequest:Has("result") then do:
                    message "Tracking:" this-object:trackingABLObjects(oAgent:GetCharacter("agentId")).
                    this-object:ParseABLObjectReport(oAgent:GetCharacter("agentId")).
                end. /* Has Result */
            end.
        end. /* do */

        catch err as Progress.Lang.Error:
            oLogger:Error("Error in trackABLObjects").
            oLogger:Error(err:GetMessage(1)).
            return error "Error in trackABLObjects".
        end catch.
        finally:
            delete object oRequest.
        end finally.
    end method. /* trackABLObjects */


    method public logical trackingABLObjects ( input pcAgentID as character ):
        define variable cRequestURI as character  no-undo.
        define variable oRequest    as JsonObject no-undo.

        Assert:NotNullOrEmpty(pcAgentID).

        /* Build the initial URL, to obtain the tracking flag. */
        assign cRequestURI = substitute("&1&2&3&4",
                                        this-object:InstanceURI, this-object:ManagerURI,
                                        this-object:GetAgentURI, this-object:TrackingObjects).

        /* Replace PAS instance name and specific Agent ID. */
        assign cRequestURI = substitute(cRequestURI,
                                        this-object:ApplicationName, pcAgentID).

        /* Make the request to the endpoint. */
        assign oRequest = cast(this-object:InvokeAPI(cRequestURI), JsonObject).

        if oRequest:Has("result") then do:
message "Tracking:" string(oRequest:GetJsonObject("result"):GetJsonText()).
            return logical(oRequest:GetLogical("result")).
        end. /* Has Result */

        return ?.

        catch err as Progress.Lang.Error:
            oLogger:Error("Error in trackingABLObjects").
            oLogger:Error(err:GetMessage(1)).
            return error "Error in trackingABLObjects".
        end catch.
        finally:
            delete object oRequest.
        end finally.
    end method. /* trackABLObjects */


    method public void ParseABLObjectReport ( input pcAgentID as character ):
        define variable cRequestURI as character  no-undo.
        define variable oRequest    as JsonObject no-undo.
        define variable oEntry      as JsonObject no-undo.
        define variable oABLOutput  as JsonObject no-undo.
        define variable oABLObjects as JsonArray  no-undo.
        define variable oABLObject  as JsonObject no-undo.
        define variable oParsed     as JsonArray  no-undo.
        define variable ix          as integer    no-undo.
        define variable iy          as integer    no-undo.

        Assert:NotNullOrEmpty(pcAgentID).

        /* Build the initial URL, to obtain ABLObjects report. */
        assign cRequestURI = substitute("&1&2&3&4",
                                        this-object:InstanceURI, this-object:ManagerURI,
                                        this-object:GetAgentURI, this-object:GetObjectsReport).

        /* Replace PAS instance name and specific Agent ID. */
        assign cRequestURI = substitute(cRequestURI, this-object:ApplicationName, pcAgentID).

        /* Make the request to the endpoint. */
        assign oRequest = cast(this-object:InvokeAPI(cRequestURI), JsonObject).

        oLogger:Trace("Parsed JsonObject is as below").
        oLogger:Trace(string(oRequest:GetJsonText())).

        assign oParsed = new JsonArray().

        if oRequest:Has("result") then do:
            assign oABLOutput = oRequest:GetJsonObject("result"):GetJsonObject("ABLOutput").
            assign oABLObjects = oABLOutput:GetJsonArray("ABLObjects").

            do while ix le oABLObjects:Length:

                assign oABLObject = oABLObjects:GetJsonObject(ix).
                if oABLObject:GetJsonArray("Objects"):Length gt 0 then do:

                    do while iy le oABLObject:GetJsonArray("Objects"):Length:
                        oEntry = new JsonObject().

                        if oABLObject:GetJsonArray("Objects"):GetJsonObject(iy):Has("ObjType") then
                            oEntry:Add("ObjType",oABLObject:GetJsonArray("Objects"):GetJsonObject(iy):GetCharacter("ObjType")).
                        else do:
                            oLogger:Error("ObjType not available in the payload").
                            oLogger:Error(string(oABLObject:GetJsonArray("Objects"):GetJsonObject(iy):GetJsonText())).
                        end.

                        if oABLObject:GetJsonArray("Objects"):GetJsonObject(iy):Has("Source") then
                            oEntry:Add("Source",oABLObject:GetJsonArray("Objects"):GetJsonObject(iy):GetCharacter("Source")).
                        else do:
                            oLogger:Error("ObjType not available in the payload").
                            oLogger:Error(string(oABLObject:GetJsonArray("Objects"):GetJsonObject(iy):GetJsonText())).
                        end.

                        if oABLObject:GetJsonArray("Objects"):GetJsonObject(iy):Has("Line") then
                            oEntry:Add("Line", oABLObject:GetJsonArray("Objects"):GetJsonObject(iy):GetInteger("Line")).
                        else do:
                            oLogger:Error("Line not available in the payload").
                            oLogger:Error(string(oABLObject:GetJsonArray("Objects"):GetJsonObject(iy):GetJsonText())).
                        end.

                        oParsed:Add(oEntry).
                        assign iy = iy + 1.
                    end. /* do while iy */

                end. /* length gt 0 */

                assign ix = ix + 1.
            end. /* do while ix */
        end. /* has response */

        oLogger:Info(substitute("Total objects found: &1", oParsed:Length)).
        oLogger:Info("Parsed output from ABLObjects report:").
        oLogger:Info(string(oParsed:GetJsonText())).

        catch err as Progress.Lang.Error:
            oLogger:Error("Failed in ParseABLObjectsReport").
            oLogger:Error(err:GetMessage(1)).
            return error "Error in ParseABLObjectsReport".
        end catch.
        finally:
            delete object oRequest.
        end finally.
    end method. /* ParseABLObjectReport */

end class.
