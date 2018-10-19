/**
 * Adjust the current sequence values based on the initially-loaded records.
 * This avoids the need for a separate sequence values file, but expects
 * that the schema already contains all of the expected sequences.
 */

using Progress.Lang.*.

message "Settings Sequences..." view-as alert-box.

do:
    define variable iNextValue as integer no-undo.

    for last Bin by Bin.BinNum:
        assign iNextValue = Bin.BinNum + 1.
    end.
    message "Bin:" iNextValue.
    current-value(NextBinNum) = iNextValue.

    for last Customer by Customer.CustNum:
        assign iNextValue = Customer.CustNum + 5.
    end.
    message "Customer:" iNextValue.
    current-value(NextCustNum) = iNextValue.

    for last Employee by Employee.EmpNum:
        assign iNextValue = Employee.EmpNum + 1.
    end.
    message "Employee:" iNextValue.
    current-value(NextEmpNum) = iNextValue.

    for last Invoice by Invoice.InvoiceNum:
        assign iNextValue = Invoice.InvoiceNum.
    end.
    message "Invoice:" iNextValue.
    current-value(NextInvNum) = iNextValue.

    for last InventoryTrans by InventoryTrans.InvTransNum:
        assign iNextValue = InventoryTrans.InvTransNum + 1.
    end.
    message "InventoryTrans:" iNextValue.
    current-value(NextInvTransNum) = iNextValue.

    for last Item by Item.ItemNum:
        assign iNextValue = Item.ItemNum + 1.
    end.
    message "Item:" iNextValue.
    current-value(NextItemNum) = iNextValue.

    for last LocalDefault by LocalDefault.LocalDefNum:
        assign iNextValue = LocalDefault.LocalDefNum + 1.
    end.
    message "LocalDefault:" iNextValue.
    current-value(NextLocalDefNum) = iNextValue.

    for last Order by Order.OrderNum:
        assign iNextValue = Order.OrderNum + 5.
    end.
    message "Order:" iNextValue.
    current-value(NextOrdNum) = iNextValue.

    for last PurchaseOrder by PurchaseOrder.PONum:
        assign iNextValue = PurchaseOrder.PONum + 1.
    end.
    message "PurchaseOrder:" iNextValue.
    current-value(NextPONum) = iNextValue.

    for last RefCall by RefCall.CallNum:
        assign iNextValue = integer(RefCall.CallNum) + 1.
    end.
    message "RefCall:" iNextValue.
    current-value(NextRefNum) = iNextValue.

    for last Supplier by Supplier.SupplierIDNum:
        assign iNextValue = Supplier.SupplierIDNum + 1.
    end.
    message "Supplier:" iNextValue.
    current-value(NextSupplNum) = iNextValue.

    for last Warehouse by Warehouse.WarehouseNum:
        assign iNextValue = Warehouse.WarehouseNum + 1.
    end.
    message "Warehouse:" iNextValue.
    current-value(NextWareNum) = iNextValue.

end. /* do */
catch err as Error:
    message "ERROR:" err:GetMessage(1).
end catch.
finally:
    return.
end finally.
