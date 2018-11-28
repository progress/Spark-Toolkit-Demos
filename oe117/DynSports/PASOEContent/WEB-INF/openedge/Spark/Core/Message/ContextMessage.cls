using Progress.Json.ObjectModel.JsonArray from propath.
using Progress.Json.ObjectModel.JsonObject from propath.
using Spark.Core.Manager.ILoggingManager from propath.
using Spark.Core.Manager.ITranslationManager from propath.
using Spark.Core.Util.ApplicationError from propath.
using Spark.Core.Util.ErrorTypeEnum from propath.

block-level on error undo, throw.

/**
 * A Request Service Message
 */
class Spark.Core.Message.ContextMessage inherits Spark.Core.Message.AbstractMessage implements Spark.Core.Message.IContextMessage:

    define protected property ValidationErrorTableName as character initial "errorTable" no-undo get. private set.

    define public property ContextPropName as character no-undo initial  "_errors" get. private set.
    define public property ReturnValueName as character no-undo initial "_retVal" get. private set.
    define public property ReturnValue as logical initial ? no-undo get. set.

    define private variable miErrSeq   as integer no-undo initial 0.

    define protected temp-table ttError no-undo serialize-name "error"
        field errSeq     as integer   serialize-hidden
        field errType    as character serialize-name "type"
        field errMsg     as character serialize-name "msg"
        field errRow     as character serialize-name "id"
        field origErrMsg as character serialize-hidden
        index ix1 as primary errSeq
        index ix2            errType
        .

    constructor public ContextMessage ( ):

        super().

    end constructor.

    method override protected void storeProperties ( ):
        /* Not implemented here. */
    end method.

    method public void setContextPropName ( input pcName as character ):

        if (pcName gt "") eq true then
            this-object:ContextPropName = pcName.

    end method.

    method public void setReturnValueName ( input pcName as character ):

        if (pcName gt "") eq true then
            this-object:ReturnValueName = pcName.

    end method.

    /**
     * Add a message to this context object
     *
     * The Error message is translated during this function
     *
     * @param poErrType The type of error (ERROR, WARNING, INFO, etc)
     * @param pcMessage The Error Message
     */
    method public void addMessage ( input poErrType as ErrorTypeEnum, input pcMessage as character ):

        this-object:createError(poErrType:name, translateMessage(pcMessage), pcMessage).

    end method.

    /**
     * Add a message to this context object
     *
     * The Error message is translated during this function
     *
     * @param poErrType The type of error (ERROR, WARNING, INFO, etc)
     * @param poMsgGroup The group to associate with this message
     * @param pcMessage The Error Message
     */
    method public void addMessage ( input poErrType as ErrorTypeEnum, input pcMsgGroup as character, input piMsgNumber as integer ):

        this-object:createError(poErrType:name, translateMessage(pcMsgGroup, piMsgNumber), pcMsgGroup, piMsgNumber).

    end method.

    /**
     * A private method used to create the Error Message Temp-Table
     *
     * @param pcErrType The Error Type
     * @param pcMessage The already translated Message
     */
    method private void createError ( input pcErrType as character, input pcMessage as character, input pcOrigErrMsg as character ):

        find first ttError
             where ttError.errType eq pcErrType
               and ttError.errMsg eq pcMessage no-error.
        if available ttError then
            delete ttError.

        create ttError.
        assign
            miErrSeq           = miErrSeq + 1
            ttError.errSeq     = miErrSeq
            ttError.errType    = pcErrType
            ttError.errMsg     = pcMessage
            ttError.origErrMsg = pcOrigErrMsg
            .

    end method.

    method private void createError ( input pcErrType as character, input pcMessage as character, input pcMsgGroup as character, input piMsgNumber as integer ):

        this-object:createError(pcErrType, pcMessage, substitute("&1:&2", pcMsgGroup, piMsgNumber)).

    end method.

    /**
     * Get a JSON array from the error temp-table in standard OpenEdge format
     */
    method public JsonArray getMessageArray ( ):

        define variable oArray as JsonArray  no-undo.
        define variable oError as JsonObject no-undo.

        assign oArray = new JsonArray().
        for each ttError:
            assign oError = new JsonObject().
            oError:Add("_errorNum", ttError.errSeq - 1). /* By default Progress uses zero-based numbers for error counting. */
            oError:Add("_errorMsg", ttError.errMsg).
            oError:Add("_errorType", ttError.errType).
            if (ttError.errRow gt "") eq true then
                oError:Add("_errorRow", ttError.errRow).
            oArray:Add(oError).
        end.
        return oArray.

    end method.

    /**
     * Has this response got any messages at all
     *
     * @return The response contains messages
     */
    method public logical hasAnyMessages ( ):

        return can-find(first ttError).

    end method.

    /**
     * Has this response got any Information messages
     *
     * @return The response contains Information messages
     */
    method public logical hasInformation ( ):

        return can-find(first ttError where ttError.errType eq ErrorTypeEnum:information:name).

    end method.

    /**
     * Has this response got any Warning or Information messages
     *
     * @return The response contains Warning messages
     */
    method public logical hasWarnings ( ):

        return can-find(first ttError
            where (ttError.errType eq ErrorTypeEnum:warning:name or
            ttError.errType eq ErrorTypeEnum:information:name)
            and ttError.errMsg ne "").

    end method.

    /**
     * Has this response got any Error messages
     *
     * @return The response contains Error messages
     */
    method public logical hasErrors ( ):

        return can-find(first ttError
            where ttError.errMsg ne ""
              and (ttError.errType eq ErrorTypeEnum:error:name or
                   ttError.errType eq ErrorTypeEnum:fatal:name)).
    /* A record with a blank errMsg is a valid record and is used to indicate
       that a previous error message is no longer an error and can be cleared by the client
     */
    end method.

    /**
     * Remove all Warning and Information (Non-"STOP") type messages
     */
    method public void removeWarningMessages ( ):

        for each ttError:
            if ttError.errType eq ErrorTypeEnum:warning:name or
               ttError.errType eq ErrorTypeEnum:information:name then
                delete ttError.
        end.

    end method.

    /**
     * Remove messages by type
     */
    method public void removeMessages ( input poErrType as ErrorTypeEnum ):

        for each ttError where ttError.errType eq poErrType:name:
            delete ttError.
        end.

    end method.

    method private character translateMessage ( input pcMessage as character ):

        return cast(Ccs.Common.Application:StartupManager:getManager(get-class(ITranslationManager)), ITranslationManager):getTranslatedMessage(pcMessage).

    end method.

    method private character translateMessage ( input pcMsgGroup as character, input piMsgNumber as integer ):

        return cast(Ccs.Common.Application:StartupManager:getManager(get-class(ITranslationManager)), ITranslationManager):getTranslatedMessage(pcMsgGroup, piMsgNumber).

    end method.

end class.