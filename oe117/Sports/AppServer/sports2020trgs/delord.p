/***************************************************************************\
*****************************************************************************
**
**     Program: delord.p
**    Descript:
**
*****************************************************************************
\***************************************************************************/

trigger procedure for delete of Order.

/* When Orders are deleted, associated Order detail lines (OrderLine)
 * are also deleted.
 */

message "Deleting Order" OrderNum view-as alert-box information buttons ok.
for each OrderLine of Order:
    delete OrderLine.
end.
