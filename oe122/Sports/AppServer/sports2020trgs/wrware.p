/***************************************************************************\
*****************************************************************************
**
**     Program: wrware.p
**    Descript:
**
*****************************************************************************
\***************************************************************************/

trigger procedure for write of Warehouse old buffer oldWarehouse.

define variable i as integer initial 0.
define variable j as integer initial 0.

/* Check to see if the user changed the Warehouse Number */

if Warehouse.WarehouseNum ne oldWarehouse.WarehouseNum and oldWarehouse.WarehouseNum gt 0 then 
do:
    /* If user changed the Warehouse Number, find related bin and */
    /* change the Warehouse numbers.                             */
    for each Bin where Bin.WarehouseNum eq oldWarehouse.WarehouseNum:
        Bin.WarehouseNum = Warehouse.WarehouseNum.
        i = i + 1.
    end.
    if i > 0 then
        message i "bin changed to reflect the new warehouse number!"
            view-as alert-box information buttons ok.

    /* If user changed the Warehouse Number, find related inventory trans and */
    /* change the Warehouse numbers.                                          */
    for each InventoryTrans where InventoryTrans.WarehouseNum eq oldWarehouse.WarehouseNum:
        InventoryTrans.WarehouseNum = Warehouse.WarehouseNum.
        j = j + 1.
    end.
    if j > 0 then
        message j "inventory transactions changed to reflect the new warehouse number!"
            view-as alert-box information buttons ok.
end.
