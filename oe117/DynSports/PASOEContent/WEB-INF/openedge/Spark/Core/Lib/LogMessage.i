/**
 * LogMessage.i - Provide standard logMessage function/method
 * Syntax: {Spark/Core/Lib/LogMessage.i &IsClass=[true|false]}
 */

/* ***************************  Main Block  *************************** */

&if ({&IsPublic} eq true) &then
    &scoped-define ClassProtected public
    &scoped-define FunctionPrivate
&else
    &scoped-define ClassProtected protected
    &scoped-define FunctionPrivate private
&endif

&if ({&IsClass} eq true) &then
method {&ClassProtected} void logMessage
&else
function logMessage returns logical {&FunctionPrivate}
&endif
    ( pcMessage as character, pcSubSystem as character, piLogLevel as integer ):
    define variable oLogger as OpenEdge.Logging.ILogWriter no-undo.

    /* Prepare a logger using a custom name for the Spark Toolkit overall. */
    assign oLogger = OpenEdge.Logging.LoggerBuilder:GetLogger("SparkToolkit").

    case piLogLevel:
        when 0 then
            . /* Do Nothing */
        when 1 then
            oLogger:Error(pcSubSystem, pcMessage).
        when 2 then
            oLogger:Info(pcSubSystem, pcMessage).
        when 3 then
            oLogger:Debug(pcSubSystem, pcMessage).
        otherwise
            oLogger:Trace(pcSubSystem, pcMessage).
    end case.
&if ({&IsClass} eq true) &then
end method.
&else
end function.
&endif

&if ({&IsClass} eq true) &then
method {&ClassProtected} void logError
&else
function logError returns logical {&FunctionPrivate}
&endif
    ( input pcContextMessage as character, input poErr as Progress.Lang.Error, input pcSubSystem as character, input piLogLevel as integer ):
    define variable iLoop      as integer                      no-undo.
    define variable cMessage   as character                    no-undo.
    define variable oAppError  as Progress.Lang.AppError       no-undo.
    define variable oSoapError as Progress.Lang.SoapFaultError no-undo.

    do on error undo, leave:
        if poErr:GetClass():IsA(get-class(Progress.Lang.AppError)) then
        do:
            oAppError = cast(poErr, Progress.Lang.AppError).
            if (oAppError:ReturnValue gt "") eq true then
                cMessage = trim(substitute("&1 &2", cMessage, oAppError:ReturnValue)).
        end.

        do iLoop = 1 to poErr:NumMessages:
            cMessage = trim(substitute("&1 &2", cMessage, poErr:GetMessage(iLoop))).
        end.

        if poErr:GetClass():IsA(get-class(Progress.Lang.SoapFaultError)) then
        do:
            oSoapError = cast(poErr,Progress.Lang.SoapFaultError).
            if valid-handle(oSoapError:SoapFault:soap-fault-detail) then
                cMessage = trim(substitute("&1 Soap Error: &2", cMessage, string(oSoapError:SoapFault:soap-fault-detail:get-serialized()))).
            cMessage = trim(substitute("&1 Soap Fault Code: &2", cMessage, oSoapError:SoapFault:soap-fault-code)).
            cMessage = trim(substitute("&1 Soap Fault String: &2", cMessage, oSoapError:SoapFault:soap-fault-string)).
            cMessage = trim(substitute("&1 Soap Fault Actor: &2", cMessage, oSoapError:SoapFault:soap-fault-actor)).
        end.

        /* if Stack Trace on then add to the message
           You can also set this session attribute using the -errorstack startup parameter. */
        if session:error-stack-trace then
            cMessage = trim(substitute(("&1~nStack Trace:~n&2"), cMessage, poErr:CallStack)).

        /* Append contect message to message */
        cMessage = trim(substitute("&1 &2", pcContextMessage, cMessage)).

        logMessage(cMessage, pcSubSystem, piLogLevel).
    end.
&if ({&IsClass} eq true) &then
end method.
&else
end function.
&endif
