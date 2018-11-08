/* Adjust dates in the Sports database to be more "modern". */

using Progress.Lang.*.
using OpenEdge.Core.*.

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
    assign dStartDate = add-interval(today, -3, DateTimeAddIntervalEnum:Months:ToString()).
    assign iMonthDiff = interval(dStartDate, dLastDate, DateTimeAddIntervalEnum:Months:ToString()).

    message "Latest Date:" dLastDate skip
            "Months Difference:" iMonthDiff view-as alert-box.

    if iMonthDiff gt 0 then do:
        /* Advance dates in order table by number of days difference. */
        message "Updating Order..." view-as alert-box.
        for each Order exclusive-lock:
            if Order.OrderDate ne ? then
                assign Order.OrderDate = add-interval(Order.OrderDate, iMonthDiff, DateTimeAddIntervalEnum:Months:ToString()).
            if Order.ShipDate ne ? then
                assign Order.ShipDate = add-interval(Order.ShipDate, iMonthDiff, DateTimeAddIntervalEnum:Months:ToString()).
            if Order.PromiseDate ne ? then
                assign Order.PromiseDate = add-interval(Order.PromiseDate, iMonthDiff, DateTimeAddIntervalEnum:Months:ToString()).
        end.

        /* Advance dates in inventory table by number of days difference. */
        message "Updating InventoryTrans..." view-as alert-box.
        for each InventoryTrans exclusive-lock:
            if InventoryTrans.TransDate ne ? then
                assign InventoryTrans.TransDate = add-interval(InventoryTrans.TransDate, iMonthDiff, DateTimeAddIntervalEnum:Months:ToString()).
        end.
        
        /* Advance dates in invoice table by number of days difference. */
        message "Updating Invoice..." view-as alert-box.
        for each Invoice exclusive-lock:
            if Invoice.InvoiceDate ne ? then
                assign Invoice.InvoiceDate = add-interval(Invoice.InvoiceDate, iMonthDiff, DateTimeAddIntervalEnum:Months:ToString()).
        end.

        /* Advance dates in purchase order table by number of days difference. */
        message "Updating PurchaseOrder..." view-as alert-box.
        for each PurchaseOrder exclusive-lock:
            if PurchaseOrder.DateEntered ne ? then
                assign PurchaseOrder.DateEntered = add-interval(PurchaseOrder.DateEntered, iMonthDiff, DateTimeAddIntervalEnum:Months:ToString()).
            if PurchaseOrder.ReceiveDate ne ? then
                assign PurchaseOrder.ReceiveDate = add-interval(PurchaseOrder.ReceiveDate, iMonthDiff, DateTimeAddIntervalEnum:Months:ToString()).
        end.

        /* Advance dates in reference call table by number of days difference. */
        message "Updating RefCall..." view-as alert-box.
        for each RefCall exclusive-lock:
            if RefCall.CallDate ne ? then
                assign RefCall.CallDate = add-interval(RefCall.CallDate, iMonthDiff, DateTimeAddIntervalEnum:Months:ToString()).
        end.

        /* Advance dates in timesheet table by number of days difference. */
        message "Updating Timesheet..." view-as alert-box.
        for each Timesheet exclusive-lock:
            if Timesheet.DayRecorded ne ? then
                assign Timesheet.DayRecorded = add-interval(Timesheet.DayRecorded, iMonthDiff, DateTimeAddIntervalEnum:Months:ToString()).
        end.

        /* Advance dates in vacation table by number of days difference. */
        message "Updating Vacation..." view-as alert-box.
        for each Vacation exclusive-lock:
            if Vacation.StartDate ne ? then
                assign Vacation.StartDate = add-interval(Vacation.StartDate, iMonthDiff, DateTimeAddIntervalEnum:Months:ToString()).
            if Vacation.EndDate ne ? then
                assign Vacation.EndDate = add-interval(Vacation.EndDate, iMonthDiff, DateTimeAddIntervalEnum:Months:ToString()).
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
    assign dStartDate = add-interval(today, -10, DateTimeAddIntervalEnum:Years:ToString()).
    assign iYearsDiff = interval(dStartDate, dLastDate, DateTimeAddIntervalEnum:Years:ToString()).

    message "Latest Date:" dLastDate skip
            "Years Difference:" iYearsDiff view-as alert-box.

    if iYearsDiff gt 0 then do:
        /* Advance the employee's birthdate and start date. */
        message "Updating Employee..." view-as alert-box.
        for each Employee exclusive-lock:
            assign
                Employee.Birthdate = add-interval(Employee.Birthdate, iYearsDiff, DateTimeAddIntervalEnum:Years:ToString())
                Employee.StartDate = add-interval(Employee.StartDate, iYearsDiff, DateTimeAddIntervalEnum:Years:ToString())
                .
        end.

        /* Advance the family member's birthdate and benefit date. */
        message "Updating Family..." view-as alert-box.
        for each Family exclusive-lock:
            assign
                Family.Birthdate   = add-interval(Family.Birthdate, iYearsDiff, DateTimeAddIntervalEnum:Years:ToString())
                Family.BenefitDate = add-interval(Family.BenefitDate, iYearsDiff, DateTimeAddIntervalEnum:Years:ToString())
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
