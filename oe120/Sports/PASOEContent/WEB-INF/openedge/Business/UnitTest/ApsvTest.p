/*------------------------------------------------------------------------
    File        : ApsvTest.p
    Description :
    Author(s)   : Dustin Grau
    Created     : Thu May 31 09:46:52 EDT 2018
    Notes       :
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

block-level on error undo, throw.

/* ***************************  Main Block  *************************** */

procedure HelloWorld:
    define output parameter pcOut as character no-undo.
    assign pcOut = "Hello World".
end procedure.
