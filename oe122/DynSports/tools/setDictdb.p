/*------------------------------------------------------------------------
    File        : setDictdb.p
    Purpose     : Set the "dictdb" alias for a given OpenEdge database
    Author(s)   : Dustin Grau
    Created     : Thu Nov 12 14:54:04 EST 2020
    Notes       :
------------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

block-level on error undo, throw.

define input parameter cDbName as character no-undo.

/* ***************************  Main Block  *************************** */

create alias dictdb for database value(cDbName).
