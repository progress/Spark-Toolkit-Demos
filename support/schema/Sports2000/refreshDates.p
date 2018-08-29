/* Adjust dates in the Sports database to be more "modern". */

&GLOBAL-DEFINE THROW ON ERROR UNDO, THROW

using Progress.Lang.*.
using OpenEdge.Core.*.

routine-level on error undo, throw.

define variable dLastDate as date    no-undo.
define variable iDaysDiff as integer no-undo.

/* Get the last shipping date from the order table. */
for last Order no-lock
   where Order.ShipDate ne ?
    by Order.ShipDate {&THROW}:
    assign dLastDate = Order.ShipDate.
end.

/* Number of days difference from last date and yesterday. */
assign iDaysDiff = interval(today - 1, dLastDate, DateTimeAddIntervalEnum:Days:ToString()).

message "Latest Date:" dLastDate skip
        "Days Difference:" iDaysDiff view-as alert-box.

if iDaysDiff gt 1 then do:
    /* Advance dates in order table by number of days difference. */
    for each Order exclusive-lock:
        if Order.OrderDate ne ? then
            assign Order.OrderDate = add-interval(Order.OrderDate, iDaysDiff, DateTimeAddIntervalEnum:Days:ToString()).
        if Order.ShipDate ne ? then
            assign Order.ShipDate = add-interval(Order.ShipDate, iDaysDiff, DateTimeAddIntervalEnum:Days:ToString()).
        if Order.PromiseDate ne ? then
            assign Order.PromiseDate = add-interval(Order.PromiseDate, iDaysDiff, DateTimeAddIntervalEnum:Days:ToString()).
    end.

    /* Advance dates in invoice table by number of days difference. */
    for each Invoice exclusive-lock:
        if Invoice.InvoiceDate ne ? then
            assign Invoice.InvoiceDate = add-interval(Invoice.InvoiceDate, iDaysDiff, DateTimeAddIntervalEnum:Days:ToString()).
    end.

    /* Advance dates in purchase order table by number of days difference. */
    for each PurchaseOrder exclusive-lock:
        if PurchaseOrder.DateEntered ne ? then
            assign PurchaseOrder.DateEntered = add-interval(PurchaseOrder.DateEntered, iDaysDiff, DateTimeAddIntervalEnum:Days:ToString()).
        if PurchaseOrder.ReceiveDate ne ? then
            assign PurchaseOrder.ReceiveDate = add-interval(PurchaseOrder.ReceiveDate, iDaysDiff, DateTimeAddIntervalEnum:Days:ToString()).
    end.
end.
