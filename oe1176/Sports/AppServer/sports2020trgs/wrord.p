/***************************************************************************\
*****************************************************************************
**
**     Program: wrord.p
**    Descript:
**
*****************************************************************************
\***************************************************************************/

trigger procedure for write of Order old buffer oldOrder.

define variable i as integer initial 0.
define variable j as integer initial 0.
define variable k as integer initial 0.

/* Check to see if the user changed the Order Number */

if Order.OrderNum ne oldOrder.OrderNum then
do:
    /* If user changed the Order Number, find related order lines and */
    /* change their order numbers.                                    */
    for each OrderLine where OrderLine.OrderNum eq oldOrder.OrderNum:
        OrderLine.OrderNum = Order.OrderNum.
        i = i + 1.
    end.
    if i > 0 then
        message i "order lines changed to reflect the new order number!"
            view-as alert-box information buttons ok.

    /* If user changed the Order Number, find related invoices and */
    /* change their order numbers.                                 */
    for each Invoice where Invoice.OrderNum eq oldOrder.OrderNum:
        Invoice.OrderNum = Order.OrderNum.
        j = j + 1.
    end.
    if j > 0 then
        message j "invoices changed to reflect the new order number!"
            view-as alert-box information buttons ok.

    /* If user changed the Order Number, find related inventory trans and */
    /* change their order numbers.                                        */
    for each InventoryTrans where InventoryTrans.OrderNum eq oldOrder.OrderNum:
        InventoryTrans.OrderNum = Order.OrderNum.
        k = k + 1.
    end.
    if k > 0 then
        message k "inventory transactions changed to reflect the new order number!"
            view-as alert-box information buttons ok.
end.
