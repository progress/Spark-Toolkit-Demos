/* Adjust dates in the Sports database to be more "modern". */

using Progress.Lang.*.
using OpenEdge.Core.*.

block-level on error undo, throw.

define variable dLastDate  as date    no-undo.
define variable iDaysDiff  as integer no-undo.
define variable iYearsDiff as integer no-undo.

/* ***************************  Main Block  *************************** */

do:
	/* Get the last shipping date from the order table to adjust all Orders, Invoices, and PO's by an equal amount. */
	for last Order no-lock
	   where Order.ShipDate ne ?
		  by Order.ShipDate:
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
	end. /* iDaysDiff */

	/* Get the youngest family member based on birthdate prior to 2010 (a millennial family). */
	for last Family no-lock
	   where Family.Birthdate lt 1/1/2010
		  by Family.Birthdate:
		assign dLastDate = Family.Birthdate.
	end.

	/* Number of years difference from last date and 2010. */
	assign iYearsDiff = interval(1/1/2010, dLastDate, DateTimeAddIntervalEnum:Years:ToString()).

	message "Latest Date:" dLastDate skip
			"Years Difference:" iYearsDiff view-as alert-box.

	if iYearsDiff gt 1 then do:
		/* Advance the employee's birthdate and start date. */
		for each Employee exclusive-lock:
			assign
				Employee.Birthdate = add-interval(Employee.Birthdate, iYearsDiff, DateTimeAddIntervalEnum:Years:ToString())
				Employee.StartDate = add-interval(Employee.StartDate, iYearsDiff, DateTimeAddIntervalEnum:Years:ToString())
				.
		end.

		/* Advance the family member's birthdate and benefit date. */
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
