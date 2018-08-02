/*------------------------------------------------------------------------
    File        : DOHEventHandler
    Purpose     : Provide event listeners for the OpenEdge DOH class
    Description :
    Author(s)   : Peter Judge (pjudge) and Dustin Grau (dgrau)
    Created     : Thu Jul 21 16:06:27 EDT 2016
    Notes       : Create new instance in startup.p
                  Can only be used with 11.6.3 or later.
  ----------------------------------------------------------------------*/

&GLOBAL-DEFINE MIN_VERSION_11_7_2 (lookup(substring(proversion(1), 1, 6), "11.6.3,11.6.4,11.6.5,11.7.0,11.7.1") = 0)

block-level on error undo, throw.

using Progress.Lang.* from propath.
using Progress.Json.ObjectModel.* from propath.
using OpenEdge.Core.* from propath.
using OpenEdge.Logging.* from propath.
using OpenEdge.Net.HTTP.HttpHeader from propath.
using OpenEdge.Net.HTTP.StatusCodeEnum from propath.
using OpenEdge.Net.HTTP.StatusCodeHelper from propath.
using OpenEdge.Web.DataObject.* from propath.
using OpenEdge.Web.SendExceptionError from propath.
using Spark.Core.Manager.ICatalogManager from propath.
using Spark.Core.Manager.ServiceLifeCycleEnum from propath.
using Spark.Core.Service.ISparkEntity from propath.

class Spark.Core.Handler.DOHEventHandler use-widget-pool final:

    /* Circular dependency to cheat death (aka GC). */
    define private variable oCheat as Spark.Core.Handler.DOHEventHandler no-undo.

    /* Used to track the start of execution for a request. */
    define private variable dInvokeTime as datetime no-undo.

    /* Contains the current Client-Principal token for this request. */
    define private variable oPrincipal as OpenEdge.Security.Principal no-undo.

    /* Access the service-level logging manager. */
    define protected property oLogger as ILogWriter no-undo
        get():
            /* Create single logger instance for this class. */
            if not valid-object(oLogger) then
                assign oLogger = LoggerBuilder:GetLogger(this-object:getClass()).
            return oLogger.
        end get.
        private set.

    /* Access the Spark catalog manager to obtain service metadata. */
    define protected property oCatalog as ICatalogManager no-undo
        get():
            /* Create single catalog instance for this class. */
            if not valid-object(oCatalog) then
                assign oCatalog = cast(Ccs.Common.Application:StartupManager:getManager(get-class(ICatalogManager)), ICatalogManager).
            return oCatalog.
        end get.
        private set.

    constructor public DOHEventHandler():
        assign oCheat = this-object.

        DataObjectHandler:LoadEntity:Subscribe(this-object:LoadEntityHandler).
        DataObjectHandler:Invoking:Subscribe(this-object:InvokingHandler).
        DataObjectHandler:Invoked:Subscribe(this-object:InvokedHandler).
        DataObjectHandler:OperationError:Subscribe(this-object:OperationErrorHandler).
        &IF {&MIN_VERSION_11_7_2} &THEN
        /* Only available for 11.7.2 and later. */
        DataObjectHandler:DiscoverService:Subscribe(this-object:DiscoverServiceHandler).
        DataObjectHandler:UnloadEntity:Subscribe(this-object:UnloadEntityHandler).
        &ENDIF
    end constructor.

    destructor DOHEventHandler():
        DataObjectHandler:LoadEntity:Unsubscribe(this-object:LoadEntityHandler).
        DataObjectHandler:Invoking:Unsubscribe(this-object:InvokingHandler).
        DataObjectHandler:Invoked:Unsubscribe(this-object:InvokedHandler).
        DataObjectHandler:OperationError:Unsubscribe(this-object:OperationErrorHandler).
        &IF {&MIN_VERSION_11_7_2} &THEN
        /* Only available for 11.7.2 and later. */
        DataObjectHandler:DiscoverService:Unsubscribe(this-object:DiscoverServiceHandler).
        DataObjectHandler:UnloadEntity:Unsubscribe(this-object:UnloadEntityHandler).
        &ENDIF
    end destructor.


    /***** Helper Methods *****/


    method private void SessionCleanup ( ):
        /* Always end this session for the current user (apply "reset" CP token). */
        Ccs.Common.Application:SessionManager:endRequestEnvironment().
        delete object oPrincipal no-error. /* Delete the CP token. */
    end method. /* SessionCleanup */


    method private character GetStatusReason ( input piStatusCode as integer ).
        define variable cReason as character no-undo.

        case piStatusCode: /* Provide standard or custom reasons for an HTTP status. */
            when 200 then cReason = StatusCodeHelper:GetMessage(StatusCodeEnum:OK).
            when 201 then cReason = StatusCodeHelper:GetMessage(StatusCodeEnum:Created).
            when 204 then cReason = StatusCodeHelper:GetMessage(StatusCodeEnum:NoContent).
            when 404 then cReason = StatusCodeHelper:GetMessage(StatusCodeEnum:NotFound).
            when 409 then cReason = StatusCodeHelper:GetMessage(StatusCodeEnum:Conflict).
            when 418 then cReason = "I'm a teapot". /* Legit status, per RFC2324 ;) */
            when 429 then cReason = StatusCodeHelper:GetMessage(StatusCodeEnum:TooManyRequests).
            when 500 then cReason = StatusCodeHelper:GetMessage(StatusCodeEnum:InternalServerError).
            when 502 then cReason = StatusCodeHelper:GetMessage(StatusCodeEnum:BadGateway).
            when 503 then cReason = StatusCodeHelper:GetMessage(StatusCodeEnum:ServiceUnavailable).
        end case.

        return cReason.
    end method. /* GetStatusReason */


    method private character extent 2 SplitServicePath (input pcPath as character):
        /**
         * Splits a URI path into a service and service-relative-uri.
         * Can be used for tokenised paths or 'real' paths.
         * -Method borrowed from OE.W.DO.DataObjectHandler for consistency
         */
        define variable cPath as character case-sensitive extent 2 no-undo.

        Assert:NotNull(pcPath, "Path info").

        /* PathInfo is going to be /pdo/service/resource/blah or /service/resource/blah  */
        assign
            cPath[2] = trim(pcPath, "/":u)
            cPath[1] = entry(1, cPath[2], "/":u)
            .

        /* Could be /pdo/ or /something-else-service */
        if cPath[1] eq "pdo":u then do:
            if num-entries(cPath[2], "/":u) ge 2 then
                assign cPath[1] = trim(entry(2, cPath[2], "/":u), "/":u)
                       // Remove the service component from the path
                       entry(2, cPath[2], "/":u) = "":u.
            else
                assign cPath[1] = "":u.
        end.

        /* Remove the pdo service component from the path */
        assign entry(1, cPath[2], "/":u) = "":u
               cPath[2] = trim(cPath[2], "/":u)
               .
        /* We don't want a blank key so we use "ROOT" */
        if cPath[1] eq "":u then
            assign cPath[1] = ServiceRegistry:ROOT_SERVICE_NAME.

        /* We don't want a blank uri so we use "/" */
        if cPath[2] eq "":u then
            assign cPath[2] = ServiceRegistry:ROOT_SERVICE_URI.

        return cPath.
    end method. /* SplitServicePath */


    /***** Event Methods *****/


    /* Event published to discover information about an available service.
     * eg. Determine the API version based on URL or header information.
     * @param Progress.Lang.Object The handler publishing the event
     * @param ServiceDiscoveryEventArgs Event args for this event
     */
    method private void DiscoverServiceHandler ( input poSender    as Progress.Lang.Object,
                                                 input poEventArgs as ServiceDiscoveryEventArgs):
        /* Existing pattern uses the URL path to determine the name and URI of the current service being requested,
         * essentially the part after the /web/<prefix>/ segment of our request. Once the name and URI of the service
         * has been isolated, use either poEventArgs:Registry or ServiceRegistry object instance is consulted via
         * HasService() and GetService() by poEventArgs:Name and poEventArgs:Version and assigned to poEventArgs:Service.
         * The default pattern is /pdo[[/{version}]/{service}] but could be adjusted to meet your needs.
         *
         * Note that the ServiceRegistry will attempt to load an implementation of the class from the CCS ServiceManager,
         * or otherwise fall back to implementing the default class. When a .map file is present, it is the job of the
         * ServiceRegistryLoader to configure each available service in the registry by use of the PutOperation and
         * related methods in the ServiceRegistry implementation.
         */
        define variable cServicePaths as character extent no-undo.
        define variable iStartTime    as integer          no-undo.

        /* If we have a service, or something already went wrong, return. */
        if valid-object(poEventArgs:Service) or poEventArgs:Cancel or valid-object(poEventArgs:Error) then return.

        assign iStartTime = mtime. /* Record start of discovery process. */

        /**
         * We have a default name algorithm to obtain the service name and relative resource URI.
         * These will be used to identify the potential entity to use, as well as the operation URI.
         */
        if String:IsNullOrEmpty(poEventArgs:Name) then
            assign
                cServicePaths          = SplitServicePath(poEventArgs:Request:PathInfo)
                poEventArgs:Name       = cServicePaths[1]
                poEventArgs:ServiceURI = cServicePaths[2]
                poEventArgs:Registry   = ServiceRegistry:Registry
                .

        /* Output the parsed service-related values as seen by the registry. */
        oLogger:Debug(substitute("DISCOVER - WebApp: &1 | Path: &2 | Service: &3 v&4 | URI: &5",
                                 poEventArgs:Request:WebAppPath, poEventArgs:Request:PathInfo,
                                 poEventArgs:Name, SemanticVersion:Parse(poEventArgs:version),
                                 poEventArgs:ServiceURI)).

        /* Output info about what is about to be loaded as the service, if found to be available. */
        oLogger:Debug(substitute("DISCOVER - &1 &2", poEventArgs:Request:Method, poEventArgs:Request:URI:ToString())).

        /* Consult the built-in registry which implements IServiceRegistry. */
        if valid-object(poEventArgs:Registry) then
            if poEventArgs:Registry:HasService(poEventArgs:Name, poEventArgs:Version) then
                assign poEventArgs:Service = poEventArgs:Registry:GetService(poEventArgs:Name, poEventArgs:Version).

        /**
         * Attempt to locate and register an available service from the Spark Toolkit metadata. In this use-case the available
         * entities are dynamically discovered through class reflection and configured with specific URI patterns and verbs for
         * access. This data can be converted into a compatible format as used by the OE.W.DO.ServiceRegistry and DOH classes.
         */
        oLogger:Trace(substitute("DISCOVER - Service '&1' Exists: &2", poEventArgs:Name, valid-object(poEventArgs:Service))).
        if not valid-object(poEventArgs:Service) then do:
            /* Register the service from local catalog metadata. */
            if valid-object(oCatalog) then do:
                /* Log this service registration being performed. */
                oLogger:Debug(substitute("DISCOVER - Registering Service: '&1' v&2", poEventArgs:Name, SemanticVersion:Parse(poEventArgs:Version))).

                /* Utilize the catalog manager to obtain service information. */
                oCatalog:registerService(poEventArgs:Registry, poEventArgs:Name, SemanticVersion:Parse(poEventArgs:Version)).
            end. /* Valid Catalog Manager */

            /* Attempt to obtain the new service, failing appropriately if not valid and setting event args if available. */
            if not poEventArgs:Registry:HasService(poEventArgs:Name, poEventArgs:Version) then do:
                oLogger:Debug(substitute("Service not found for '&1 &2'",
                                         poEventArgs:Request:Method, poEventArgs:Request:URI:ToString())).
                undo, throw new SendExceptionError(StatusCodeEnum:NotFound,
                                                   new AppError(substitute("Service not found for '&1 &2'",
                                                                           poEventArgs:Request:Method,
                                                                           poEventArgs:Request:URI:ToString()), 0)).
            end. /* Not Valid */
            assign poEventArgs:Service = poEventArgs:Registry:GetService(poEventArgs:Name, poEventArgs:Version).
        end. /* No Service */

        /**
         * If we do not have a registered service by now, the default logic will look on disk for a .GEN and/or .MAP file.
         */
        oLogger:Trace(substitute("DISCOVER - Completed in &1(ms)", trim(string((mtime - iStartTime), ">>>,>>9")))).

        catch err as Progress.Lang.Error:
            assign poEventArgs:Error = err.
            oLogger:Error(substitute("DISCOVER - &1: &2", poEventArgs:ServiceURI, err:GetMessage(1))).
        end catch.
    end method. /* DiscoverServiceHandler */


    /* Event published to invoke/load a piece of business logic (aka Business Entity).
     * If none exists, we try a simple DYNAMIC-NEW.
     * @param Progress.Lang.Object The handler publishing the event
     * @param HandlerLoadEntityEventArgs Event args for this event
     */
    method private void LoadEntityHandler ( input poSender    as Progress.Lang.Object,
                                            input poEventArgs as HandlerLoadEntityEventArgs ):
        /* Leave a log message that the DOH event handler is being loaded. */
        oLogger:Debug(substitute("DOH-LOAD - Requested Entity '&1'", poEventArgs:Operation:TargetName)).

        /* Attempt to load the requested service for this business entity. */
        define variable oServiceClass as Progress.Lang.Class no-undo.
        assign oServiceClass = Progress.Lang.Class:GetClass(poEventArgs:Operation:TargetName) no-error.
        if valid-object(oServiceClass) then do:
            /* Start and obtain a service class instance from the local CCS ServiceManager implementation. */
            assign poEventArgs:BusinessEntity = Ccs.Common.Application:ServiceManager:getService(oServiceClass).

            /* Leave a log message that the DOH event handler has been loaded. */
            oLogger:Debug(substitute("DOH-LOAD - Located Entity '&1'", oServiceClass:TypeName)).
        end. /* valid-object */
    end method. /* LoadEntityHandler */


    /* Event published before the business logic function is called by the handler.
     * @param Progress.Lang.Object The handler publishing the event
     * @param OperationInvocationEventArgs Event args for this event
     */
    method private void InvokingHandler ( input poSender    as Progress.Lang.Object,
                                          input poEventArgs as OperationInvocationEventArgs ):
        assign dInvokeTime = now. /* Remember when we start execution. */

        if poEventArgs:Operation:ServiceURI eq "/" then
            oLogger:Debug(substitute("INVOKING - &1 /&2 (&3)",
                                     string(poEventArgs:Operation:Method),
                                     poEventArgs:Operation:ServiceName,
                                     poEventArgs:Operation:TargetName)).
        else
            oLogger:Debug(substitute("INVOKING - &1 /&2/&3 -> &4:&5",
                                     string(poEventArgs:Operation:Method),
                                     poEventArgs:Operation:ServiceName,
                                     poEventArgs:Operation:ServiceURI,
                                     poEventArgs:Operation:TargetName,
                                     poEventArgs:Operation:TargetFunction)).

        /**
         * Assert the current user's identity for this session request.
         *
         * Note: For working with anonymous security, ensure the following are set:
         *  OEClientPrincipalFilter.anonymous=true
         *  OEClientPrincipalFilter.sealAnonymous=true
         *  OEClientPrincipalFilter.passthru=true
         */
        assign oPrincipal = OpenEdge.Security.Principal:Import(session:current-request-info).
        Ccs.Common.Application:SessionManager:establishRequestEnvironment(oPrincipal:Token).

        catch err as Progress.Lang.Error:
            assign poEventArgs:Error = err.
            oLogger:Error(substitute("INVOKING - &1: &2", poEventArgs:Operation:TargetName, err:GetMessage(1))).
        end catch.
    end method. /* InvokingHandler */


    /* Event published after the business logic function was called by the handler.
     * @param Progress.Lang.Object The handler publishing the event
     * @param OperationInvocationEventArgs Event args for this event
     */
    method private void InvokedHandler ( input poSender    as Progress.Lang.Object,
                                         input poEventArgs as OperationInvocationEventArgs ):
        if poEventArgs:Operation:ServiceURI eq "/" then
            oLogger:Debug(substitute("INVOKED_ - &1 /&2 (&3)",
                                     string(poEventArgs:Operation:Method),
                                     poEventArgs:Operation:ServiceName,
                                     poEventArgs:Operation:TargetName)).
        else
            oLogger:Debug(substitute("INVOKED_ - &1 /&2/&3 -> &4:&5",
                                     string(poEventArgs:Operation:Method),
                                     poEventArgs:Operation:ServiceName,
                                     poEventArgs:Operation:ServiceURI,
                                     poEventArgs:Operation:TargetName,
                                     poEventArgs:Operation:TargetFunction)).

        /* If dealing with a READ operation from an ISparkEntity class, attempt to get
         * the last-known number of records read and return as part of the response object.
         */
        if poEventArgs:BusinessEntity:GetClass():IsA(get-class(ISparkEntity)) and
           poEventArgs:Operation:Method eq OpenEdge.Net.HTTP.MethodEnum:get and
           poEventArgs:Operation:TargetFunction matches "Read*" then do on error undo, throw:
            define variable oData   as JsonObject   no-undo.
            define variable oEntity as ISparkEntity no-undo.

            /* Cast to JSON object if found to be of valid type. */
            if valid-object(poEventArgs:Response:Entity) and
               type-of(poEventArgs:Response:Entity, JsonObject) then do:
                assign oData = cast(poEventArgs:Response:Entity, JsonObject).

                /* Append a record count property to the outbound object. */
                if valid-object(oData) and not oData:Has("numRecs") then do:
                    assign oEntity = cast(poEventArgs:BusinessEntity, ISparkEntity).
                    if valid-object(oEntity) then
                        oData:Add("numRecs", oEntity:LastCount).
                    poEventArgs:Response:Entity = cast(oData:Clone(), JsonObject).
                end. /* Valid JSON */
            end. /* Valid Entity */

            finally:
                delete object oData no-error.
                /* Note: Do not delete oEntity here, as that removes the cached BusinessEntity instance from the DOH. */
            end finally.
        end. /* Read Operation */

        if dInvokeTime ne ? then do on error undo, throw:
            define variable fElapsed as decimal    no-undo initial 0.
            define variable oHeader  as HttpHeader no-undo.

            /* Add the elapsed time for this request as a header value. */
            assign fElapsed = interval(now, dInvokeTime, string(OpenEdge.Core.DateTimeAddIntervalEnum:Milliseconds)) / 1000.

            assign oHeader = new HttpHeader("X-Elapsed", trim(string(fElapsed, ">>>9.99")) + "sec.").
            poEventArgs:Response:SetHeader(oHeader).
        end. /* iStart gt 0 */

        catch err as Progress.Lang.Error:
            assign poEventArgs:Error = err.
            oLogger:Error(substitute("INVOKED_ - &1: &2", poEventArgs:Operation:TargetName, err:GetMessage(1))).
        end catch.
        finally:
            this-object:SessionCleanup(). /* Perform any necessary cleanup. */
        end finally.
    end method. /* InvokedHandler */


    /* Event published when an error is encountered.
     * @param Progress.Lang.Object The handler publishing the event
     * @param HandlerErrorEventArgs Event args for this event
     */
    method private void OperationErrorHandler ( input poSender    as Progress.Lang.Object,
                                                input poEventArgs as HandlerErrorEventArgs ):
        oLogger:Error(substitute("OP-ERROR - &1: &2", poEventArgs:Operation:TargetName, poEventArgs:Error)).

        define variable iCode as integer no-undo.
        assign iCode = poEventArgs:Error:GetMessageNum(1).
        if iCode lt 0 then
            assign iCode = iCode * -1. /* Flip negative numbers. */

        if iCode ge 200 and iCode le 599 then do:
            /* Use code as HTTP response code. */
            poEventArgs:Response:StatusCode = iCode.
            poEventArgs:Response:StatusReason = this-object:GetStatusReason(iCode).
        end.
        else do:
            /* Default to an HTTP 500/Error. */
            poEventArgs:Response:StatusCode = integer(StatusCodeEnum:InternalServerError).
            poEventArgs:Response:StatusReason = StatusCodeHelper:GetMessage(StatusCodeEnum:InternalServerError).
        end.
        poEventArgs:ReturnStatusCode = 0. /* Use event args as response. */

        finally:
            this-object:SessionCleanup(). /* Perform any necessary cleanup. */
        end finally.
    end method. /* OperationErrorHandler */


    /* Event published to unload a piece of business logic (aka Business Entity).
     * @param Progress.Lang.Object The handler publishing the event
     * @param HandlerLoadEntityEventArgs Event args for this event
     */
    method private void UnloadEntityHandler ( input poSender    as Progress.Lang.Object,
                                              input poEventArgs as HandlerLoadEntityEventArgs ):
        /* Leave a log message that the DOH event handler has been loaded. */
        Ccs.Common.Application:ServiceManager:stopServices(ServiceLifeCycleEnum:request).
        oLogger:Debug(substitute("DOH-UNLD - &1", poEventArgs:Operation:TargetName)).
    end method. /* UnloadEntityHandler */

end class.