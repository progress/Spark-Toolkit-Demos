/***************************************************************************\
*****************************************************************************
**
**     Program: delordl.p
**    Descript:
**
*****************************************************************************
\***************************************************************************/

trigger procedure for delete of OrderLine.

/* Trigger provides an information message when orderlines are deleted */

message "Deleting Order Line:" OrderLine.LineNum "Order Num:" OrderLine.OrderNum
    view-as alert-box information buttons ok.

