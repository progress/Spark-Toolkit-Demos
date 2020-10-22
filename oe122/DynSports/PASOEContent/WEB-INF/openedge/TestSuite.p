/*------------------------------------------------------------------------
    File        : TestSuite.p
    Purpose     : Run all code tests in a single procedure
    Syntax      :
    Description :
    Author(s)   : Dustin Grau
    Created     : Thu Jan 16 14:37:37 EST 2020
    Notes       :
  ----------------------------------------------------------------------*/

block-level on error undo, throw.

/* ***************************  Main Block  *************************** */

mainblk:
do on error undo, throw:
    define variable oRunCode   as Business.UnitTest.RunCode   no-undo.
    define variable oLeakyCode as Business.UnitTest.LeakyCode no-undo.

    assign oRunCode = new Business.UnitTest.RunCode().
    assign oLeakyCode = new Business.UnitTest.LeakyCode().

    define variable iElapsed as integer no-undo.
    oRunCode:lookBusy(random(2000, 4000), output iElapsed).
    message substitute("Completed 'LookBusy' in &1ms", iElapsed).

    define variable lCompleted as logical no-undo.
    oLeakyCode:badBuffer(output lCompleted).
    message substitute("Created badBuffer with result &1", lCompleted).

    define variable cMessage as character no-undo.
    oLeakyCode:badHandle(output cMessage).
    message substitute("Ran procedure with message: &1", cMessage).

    finally:
        delete object oRunCode   no-error.
        delete object oLeakyCode no-error.
    end finally.
end.
