/*------------------------------------------------------------------------
    File        : HelloProc.p
    Purpose     :
    Description :
    Author(s)   :
    Created     : Fri Apr 29 08:32:24 EDT 2016
    Notes       :
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

block-level on error undo, throw.

/* ***************************  Main Block  *************************** */

procedure sayHello:
    define input  parameter toWhom   as character no-undo.
    define output parameter greeting as character no-undo.

    assign greeting = substitute("Hello &1", toWhom).
end procedure.

procedure sayHello2Many:
    define input  parameter recipients as Progress.Json.ObjectModel.JsonArray no-undo.
    define output parameter greeting   as character no-undo.

    define variable ix as integer no-undo.
    if valid-object(recipients) then
    do ix = 1 to recipients:length:
        if recipients:GetType(ix) eq Progress.Json.ObjectModel.JsonDataType:string then
            assign greeting = substitute("&1, Hello &2", greeting, recipients:GetCharacter(ix)).
    end.

    assign greeting = trim(left-trim(greeting, ",")).
end procedure.
