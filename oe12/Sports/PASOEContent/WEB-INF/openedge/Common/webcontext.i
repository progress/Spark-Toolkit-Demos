/*------------------------------------------------------------------------
   File        : WebContext
   Purpose     :
   Syntax      :
   Description :
   Author(s)   : Code Wizard
   Created     : 02/21/18
   Notes       :
 ----------------------------------------------------------------------*/

@openapi.openedge.entity.primarykey(fields="IdentityName,ContextType,ContextViewID,ContextTitle,ContextSeqNo").
@openapi.openedge.entity.field.property(field="id", name="semanticType", value="Internal").
@openapi.openedge.entity.field.property(field="seq", name="semanticType", value="Internal").

define temp-table ttWebContext before-table bttWebContext
    field id            as character
    field seq           as integer   initial ?
    field IdentityName  as character label "Identity Name"
    field ContextType   as character label "Type"
    field ContextViewID as character label "View ID"
    field ContextTitle  as character label "Title"
    field ContextSeqNo  as integer   label "Sequence"
    field ContextData   as character label "Data"
    index pkSeq         is primary unique seq
    index idxpkWebContext          IdentityName ContextType ContextViewID ContextTitle ContextSeqNo
    .

define dataset dsWebContext for ttWebContext.
