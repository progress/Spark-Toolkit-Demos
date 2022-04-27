/*------------------------------------------------------------------------
   File        : WebRole
   Purpose     :
   Syntax      :
   Description :
   Author(s)   : Code Wizard
   Created     : 05/09/17
   Notes       :
 ----------------------------------------------------------------------*/

define temp-table ttWebRole no-undo before-table bttWebRole
    field id          as character
    field seq         as integer   initial ?
    field RoleID      as character label "Role"
    field RoleDesc    as character label "Description"
    field TaskList    as character label "Tasks"
    index pkSeq       is primary unique seq
    index idxpkRoleID is unique  RoleID
    .

define dataset dsWebRole for ttWebRole.
