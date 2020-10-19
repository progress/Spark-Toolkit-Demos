/***************************************************************************\
*****************************************************************************
**
**     Program: wrItem.p
**    Descript:
**
*****************************************************************************
\***************************************************************************/

trigger procedure for write of Item old buffer oldItem.

define variable h as integer initial 0.
define variable i as integer initial 0.
define variable j as integer initial 0.
define variable k as integer initial 0.
define variable l as integer initial 0.

/* Check to see if the user changed the Item Number */

if Item.ItemNum ne oldItem.ItemNum and oldItem.ItemNum gt 0 then
do:
    /* If user changed the Item Number, find related bin and */
    /* change their Item numbers.                            */
    for each Bin where Bin.ItemNum eq Item.ItemNum:
        Bin.ItemNum = Item.ItemNum.
        h = h + 1.
    end.
    if h > 0 then
        message h "bins changed to reflect the new item number!"
            view-as alert-box information buttons ok.

    /* If user changed the Item Number, find related order lines and */
    /* change their Item numbers.                                    */
    for each OrderLine where OrderLine.ItemNum eq Item.ItemNum:
        OrderLine.ItemNum = Item.ItemNum.
        i = i + 1.
    end.
    if i > 0 then
        message i "order lines changed to reflect the new item number!"
            view-as alert-box information buttons ok.

    /* If user changed the Item Number, find related PO lines and */
    /* change their Item numbers.                                 */
    for each POLine where POLine.ItemNum eq Item.ItemNum:
        POLine.ItemNum = Item.ItemNum.
        j = j + 1.
    end.
    if j > 0 then
        message j "PO lines changed to reflect the new item number!"
            view-as alert-box information buttons ok.

    /* If user changed the Employee Number, find related inventory trans and */
    /* change their employee numbers.                                        */
    for each InventoryTrans where InventoryTrans.ItemNum eq oldItem.ItemNum:
        InventoryTrans.ItemNum = Item.ItemNum.
        k = k + 1.
    end.
    if k > 0 then
        message k "inventory transactions changed to reflect the new item number!"
            view-as alert-box information buttons ok.

    /* If user changed the Employee Number, find related supplier xref and */
    /* change their employee numbers.                                      */
    for each SupplierItemXref where SupplierItemXref.ItemNum eq oldItem.ItemNum:
        SupplierItemXref.ItemNum = Item.ItemNum.
        l = l + 1.
    end.
    if l > 0 then
        message l "supplier X-ref changed to reflect the new item number!"
            view-as alert-box information buttons ok.
end.


/*
 * Generate Po if there is not enough qty
 */

if Item.MinQty > ((Item.OnHand - Item.Allocated) + Item.onorder) then
do:

    find first SupplierItemXref where SupplierItemXref.Itemnum eq Item.Itemnum no-lock no-error.

    if avail SupplierItemXref then
    do:

        find Supplier where Supplier.Supplieridnum eq SupplierItemXref.Supplieridnum no-lock no-error.

        if avail Supplier then
        do:
            create PurchaseOrder.
            assign
                PurchaseOrder.DateEntered   = today
                PurchaseOrder.POStatus      = "Ordered"
                PurchaseOrder.SupplierIDNum = SupplierItemXref.Supplieridnum
                .

            create POLine.
            assign
                POLine.ponum         = PurchaseOrder.ponum
                POLine.linenum       = 1
                POLine.Discount      = Supplier.discount
                POLine.Itemnum       = Item.Itemnum
                POLine.Price         = Item.price
                POLine.qty           = Item.reorder
                POLine.ExtendedPrice = (Item.price * POLine.qty) * (1 - Supplier.discount).
                Item.onorder = Item.onorder + Item.reorder
                .
        end. /* If avail suplier*/

    end. /*if avail SupplierItemXref*/

end.
