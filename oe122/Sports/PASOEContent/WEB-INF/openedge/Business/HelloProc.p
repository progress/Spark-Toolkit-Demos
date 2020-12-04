/*------------------------------------------------------------------------
    File        : HelloProc.p
    Purpose     :
    Description :
    Author(s)   :
    Created     : Fri Apr 29 08:32:24 EDT 2016
    Notes       :
  ----------------------------------------------------------------------*/

@program FILE(name="HelloProc.p", module="AppServer").
@openapi.openedge.export FILE(type="REST", executionMode="singleton", useReturnValue="false", writeDataSetBeforeImage="false").
@progress.service.resource FILE(name="HelloProc", URI="/helloworld", schemaName="", schemaFile="").

/* Proposed annotations for service assignment and API versioning. */
@openapi.openedge.service(name="tests", URI="/web/api/tests").
@openapi.openedge.resource.version(major="1", minor="0", patch="0").

block-level on error undo, throw.

/* Used for testing persistent procedures. */
define variable cUser as character no-undo.

/* Used for session-managed APSV connections. */
procedure setHelloUser:
    define input parameter toWhom as character no-undo.

    pause 0.4 no-message. /* Just add a bit of fake think-time. */

    assign cUser = toWhom.
end procedure.

/* Used for session-managed APSV connections. */
procedure sayHelloStoredUser:
    define output parameter greeting as character no-undo.

    pause 0.4 no-message. /* Just add a bit of fake think-time. */

    assign greeting = substitute("Hello &1", cUser).
end procedure.

@openapi.openedge.export(type="REST", useReturnValue="false", writeDataSetBeforeImage="false").
@progress.service.resourceMapping(type="REST", operation="invoke", URI="/hello", alias="hello", mediaType="application/json").
procedure sayHello:
    define input  parameter toWhom   as character no-undo.
    define output parameter greeting as character no-undo.

    pause 0.2. /* Just add a bit of fake think-time. */

    assign greeting = substitute("Hello &1", toWhom).
end procedure.

@openapi.openedge.export(type="REST", useReturnValue="false", writeDataSetBeforeImage="false").
@progress.service.resourceMapping(type="REST", operation="invoke", URI="/hello2Many", alias="many", mediaType="application/json").
procedure sayHello2Many:
    define input  parameter recipients as Progress.Json.ObjectModel.JsonArray no-undo.
    define output parameter greeting   as character no-undo.

    define variable ix as integer no-undo.
    if valid-object(recipients) then
    do ix = 1 to recipients:length:
        if recipients:GetType(ix) eq Progress.Json.ObjectModel.JsonDataType:string then
            assign greeting = substitute("&1, Hello &2", greeting, recipients:GetCharacter(ix)).
    end.

    pause 0.2. /* Just add a bit of fake think-time. */

    assign greeting = trim(left-trim(greeting, ",")).
end procedure.

@openapi.openedge.export(type="REST", useReturnValue="false", writeDataSetBeforeImage="false").
@progress.service.resourceMapping(type="REST", operation="invoke", URI="/helloExtent", alias="extent", mediaType="application/json").
procedure sayHelloExtent:
    define input  parameter recipients as character no-undo extent.
    define output parameter greeting   as character no-undo.

    define variable ix as integer no-undo.
    do ix = 1 to extent(recipients):
        assign greeting = substitute("&1, Hello &2", greeting, recipients[ix]).
    end.

    pause 0.2. /* Just add a bit of fake think-time. */

    assign greeting = trim(left-trim(greeting, ",")).
end procedure.
