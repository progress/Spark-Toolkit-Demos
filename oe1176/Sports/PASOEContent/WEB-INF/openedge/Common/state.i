/*------------------------------------------------------------------------
    File        : state.i
    Purpose     :
    Description :
    Author(s)   : Dustin Grau (dugrau@progress.com)
    Created     : Tue Sep 8 10:42:09 EDT 2015
    Notes       :
  ----------------------------------------------------------------------*/

@openapi.openedge.entity.primarykey(table="states", fields="Abbrev").

define temp-table states no-undo
    field Abbrev   as character
    field FullName as character
    index pkState  is primary unique Abbrev ascending
    .
