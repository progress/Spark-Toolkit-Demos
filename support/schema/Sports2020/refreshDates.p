/* Adjust dates in the Sports database to be more "modern". */

using Progress.Lang.*.

block-level on error undo, throw.

define variable dLastDate  as date    no-undo.
define variable dStartDate as date    no-undo.
define variable iMonthDiff as integer no-undo.
define variable iYearsDiff as integer no-undo.

/* ***************************  Main Block  *************************** */

do:
    /* Get the last shipping date from the order table to adjust all Orders, Invoices, and PO's by an equal amount. */
    for last Order no-lock
       where Order.ShipDate ne ?
          by Order.ShipDate:
        assign dLastDate = Order.ShipDate.
    end.

    /* Number of days difference from last date and 3 months ago (gives some buffer to dates). */
    assign dStartDate = add-interval(today, -3, "months").
    assign iMonthDiff = interval(dStartDate, dLastDate, "months").
    assign iYearsDiff = if iMonthDiff ge 12 then truncate(iMonthDiff / 12, 0) else 0.

    message "Latest Date:" dLastDate skip
            "Months Difference:" iMonthDiff skip
            "Years Difference:" iYearsDiff view-as alert-box.

    if iMonthDiff gt 0 then do:
        /* Advance dates in order table by number of months difference. */
        message "Updating Order..." view-as alert-box.
        for each Order exclusive-lock:
            if Order.OrderDate ne ? then
                assign Order.OrderDate = add-interval(Order.OrderDate, iMonthDiff, "months").
            if Order.ShipDate ne ? then
                assign Order.ShipDate = add-interval(Order.ShipDate, iMonthDiff, "months").
            if Order.PromiseDate ne ? then
                assign Order.PromiseDate = add-interval(Order.PromiseDate, iMonthDiff, "months").
        end.

        /* Advance dates in inventory table by number of months difference. */
        message "Updating InventoryTrans..." view-as alert-box.
        for each InventoryTrans exclusive-lock
           where InventoryTrans.TransDate ne ?:
            assign InventoryTrans.TransDate = add-interval(InventoryTrans.TransDate, iMonthDiff, "months").
        end.

        /* Advance dates in invoice table by number of months difference. */
        message "Updating Invoice..." view-as alert-box.
        for each Invoice exclusive-lock
           where Invoice.InvoiceDate ne ?:
            assign Invoice.InvoiceDate = add-interval(Invoice.InvoiceDate, iMonthDiff, "months").
        end.

        /* Advance dates in purchase order table by number of months difference. */
        message "Updating PurchaseOrder..." view-as alert-box.
        for each PurchaseOrder exclusive-lock:
            if PurchaseOrder.DateEntered ne ? then
                assign PurchaseOrder.DateEntered = add-interval(PurchaseOrder.DateEntered, iMonthDiff, "months").
            if PurchaseOrder.ReceiveDate ne ? then
                assign PurchaseOrder.ReceiveDate = add-interval(PurchaseOrder.ReceiveDate, iMonthDiff, "months").
        end.

        /* Advance dates in reference call table by number of months difference. */
        message "Updating RefCall..." view-as alert-box.
        for each RefCall exclusive-lock
           where RefCall.CallDate ne ?:
            assign RefCall.CallDate = add-interval(RefCall.CallDate, iMonthDiff, "months").
        end.

        /* Advance dates in timesheet table by number of years difference due to an indexed date field. */
        /* To avoid an endless loop, only update dates prior to the start of the current year. */
        message "Updating Timesheet..." view-as alert-box.
        for each Timesheet exclusive-lock
           where Timesheet.DayRecorded lt date(1, 1, year(today)):
            assign Timesheet.DayRecorded = add-interval(Timesheet.DayRecorded, iYearsDiff, "years").
        end.

        /* Advance dates in vacation table by number of years difference due to an indexed date field. */
        /* To avoid an endless loop, only update dates prior to the start of the current year. */
        message "Updating Vacation..." view-as alert-box.
        for each Vacation exclusive-lock
           where Vacation.StartDate lt date(1, 1, year(today)):
            assign Vacation.StartDate = add-interval(Vacation.StartDate, iYearsDiff, "years").
            if Vacation.EndDate ne ? then
                assign Vacation.EndDate = add-interval(Vacation.EndDate, iYearsDiff, "years").
        end.
    end. /* iMonthDiff */

    /* Get the youngest family member based on birthdate prior to 2010 (a millennial family). */
    for last Family no-lock
       where Family.Birthdate lt 1/1/2010
          by Family.Birthdate:
        assign dLastDate = Family.Birthdate.
    end.

    /**
     * Calculate the number of years difference from last date and 10 years prior to today.
     * This pushes all employees into the 30-50yr range, with similar spouse ages and young family members.
     */
    assign dStartDate = add-interval(today, -10, "years").
    assign iYearsDiff = interval(dStartDate, dLastDate, "years").

    message "Latest Date:" dLastDate skip
            "Years Difference:" iYearsDiff view-as alert-box.

    if iYearsDiff gt 0 then do:
        /* Advance the employee's birthdate and start date. */
        message "Updating Employee..." view-as alert-box.
        for each Employee exclusive-lock:
            assign
                Employee.Birthdate = add-interval(Employee.Birthdate, iYearsDiff, "years")
                Employee.StartDate = add-interval(Employee.StartDate, iYearsDiff, "years")
                .
        end.

        /* Advance the family member's birthdate and benefit date. */
        message "Updating Family..." view-as alert-box.
        for each Family exclusive-lock:
            assign
                Family.Birthdate   = add-interval(Family.Birthdate, iYearsDiff, "years")
                Family.BenefitDate = add-interval(Family.BenefitDate, iYearsDiff, "years")
                .
        end.
    end. /* iYearsDiff */
end. /* do */
catch err as Error:
    message "ERROR:" err:GetMessage(1).
end catch.
finally:
    return.
end finally.
