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
using OpenEdge.Logging.* from propath.
using OpenEdge.Core.Assert from propath.
using OpenEdge.Core.JsonDataTypeEnum from propath.
using OpenEdge.Core.String from propath.
using OpenEdge.Net.HTTP.Credentials from propath.
using OpenEdge.Net.HTTP.HttpClient from propath.
using OpenEdge.Net.HTTP.IHttpRequest from propath.
using OpenEdge.Net.HTTP.IHttpResponse from propath.
using OpenEdge.Net.HTTP.RequestBuilder from propath.
using OpenEdge.Net.HTTP.IAuthenticatedRequest from propath.
using Spark.Core.Util.ABLObjectsReport from propath.

block-level on error undo, throw.

class Spark.Core.Util.ABLObjectsReport use-widget-pool:

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

    define protected property oLogger as ILogWriter
        get():
            if not valid-object(this-object:oLogger) then
                assign this-object:oLogger = LoggerBuilder:GetLogger(get-class(ABLObjectsReport)).
            return this-object:oLogger.
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
        assign oCredentials = new Credentials(this-object:ManagerRealm, this-object:ManagerUsername, this-object:ManagerPassword).

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
        assign cRequestURI = substitute("&1&2&3", this-object:InstanceURI, this-object:ManagerURI, this-object:GetAllAgentsURI).
        assign cRequestURI = substitute(cRequestURI, this-object:ApplicationName). /* Set request with PAS instance name. */
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

        assign cRequestURI = substitute("&1&2&3", this-object:InstanceURI, this-object:ManagerURI, this-object:GetAgentURI).

        do iCount = 1 to this-object:AgentList:Length:
            /* Set request with PAS instance name and specific Agent ID. */
            assign oAgent = this-object:AgentList:GetJsonObject(iCount).
            if oAgent:Has("agentId") then do:
                assign cRequestURI = substitute(cRequestURI, this-object:ApplicationName, oAgent:GetCharacter("agentId")).
                if plEnable then
                    assign cRequestURI = substitute("&1&2", cRequestURI, this-object:TrackObjectsOn).
                else
                    assign cRequestURI = substitute("&1&2", cRequestURI, this-object:TrackObjectsOff).

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

        assign cRequestURI = substitute("&1&2&3&4", this-object:InstanceURI, this-object:ManagerURI, this-object:GetAgentURI, this-object:TrackingObjects).
        assign cRequestURI = substitute(cRequestURI, this-object:ApplicationName, pcAgentID). /* Replace PAS instance name and specific Agent ID. */
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
        define variable oABLObjects as JsonArray  no-undo.
        define variable oErrorArray as JsonArray  no-undo.
        define variable ix          as integer    no-undo.
        define variable iy          as integer    no-undo.

        Assert:NotNullOrEmpty(pcAgentID).

        assign cRequestURI = substitute("&1&2&3&4", this-object:InstanceURI, this-object:ManagerURI, this-object:GetAgentURI, this-object:GetObjectsReport).
        assign cRequestURI = substitute(cRequestURI, this-object:ApplicationName, pcAgentID). /* Replace PAS instance name and specific Agent ID. */
        assign oRequest = cast(this-object:InvokeAPI(cRequestURI), JsonObject).

        oLogger:Trace("Parsed JsonObject is as below").
        oLogger:Trace(string(oRequest:GetJsonText())).

        assign oErrorArray = new JsonArray().

        if oRequest:Has("result") then do:
            assign oABLObjects = oRequest:GetJsonObject("result"):GetJsonObject("ABLOutput"):GetJsonArray("ABLObjects").
            do while ix le oRequest:GetJsonObject("result"):GetJsonObject("ABLOutput"):GetJsonArray("ABLObjects"):Length:

                if oABLObjects:GetJsonObject(ix):GetJsonArray("Objects"):Length gt 0 then do:

                    do while iy le oABLObjects:GetJsonObject(ix):GetJsonArray("Objects"):Length:
                        oEntry = new JsonObject().

                        if oABLObjects:GetJsonObject(ix):GetJsonArray("Objects"):GetJsonObject(iy):Has("ObjType") then
                            oEntry:Add("ObjType",oABLObjects:GetJsonObject(ix):GetJsonArray("Objects"):GetJsonObject(iy):GetCharacter("ObjType")).
                        else do:
                            oLogger:Error("ObjType not available in the payload").
                            oLogger:Error(string(oABLObjects:GetJsonObject(ix):GetJsonArray("Objects"):GetJsonObject(iy):GetJsonText())).
                        end.
    
                        if oABLObjects:GetJsonObject(ix):GetJsonArray("Objects"):GetJsonObject(iy):Has("Source") then
                            oEntry:Add("Source",oABLObjects:GetJsonObject(ix):GetJsonArray("Objects"):GetJsonObject(iy):GetCharacter("Source")).
                        else do:
                            oLogger:Error("ObjType not available in the payload").
                            oLogger:Error(string(oABLObjects:GetJsonObject(ix):GetJsonArray("Objects"):GetJsonObject(iy):GetJsonText())).
                        end.
    
                        if oABLObjects:GetJsonObject(ix):GetJsonArray("Objects"):GetJsonObject(iy):Has("Line") then
                            oEntry:Add("Line", oABLObjects:GetJsonObject(ix):GetJsonArray("Objects"):GetJsonObject(iy):GetInteger("Line")).
                        else do:
                            oLogger:Error("Line not available in the payload").
                            oLogger:Error(string(oABLObjects:GetJsonObject(ix):GetJsonArray("Objects"):GetJsonObject(iy):GetJsonText())).
                        end.
    
                        oErrorArray:Add(oEntry).
                        assign iy = iy + 1.
                    end. /* do while iy */

                end. /* length gt 0 */

                assign ix = ix + 1.
            end. /* do while ix */
        end. /* Has Response */

        oLogger:Info(substitute("Total leaked objects found: &1", oErrorArray:Length)).
        oLogger:Info("Parsed output from ABLObjects report:").
        oLogger:Info(string(oErrorArray:GetJsonText())).

        catch err as Progress.Lang.Error:
            oLogger:Error("Failed in ParseABLObjectsReport").
            oLogger:Error(err:GetMessage(1)).
            return error "Error in ParseABLObjectsReport".
        end catch.
        finally:
            delete object oRequest.
        end finally.
    end method.

end class.
