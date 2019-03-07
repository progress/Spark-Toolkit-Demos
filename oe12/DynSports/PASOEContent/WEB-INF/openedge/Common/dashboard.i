/*------------------------------------------------------------------------
    File        : dashboard.i
    Purpose     : Schema definition for Dashboard statistics
    Description :
    Author(s)   : Dustin Grau (dugrau@progress.com)
    Created     : Thu Jun 04 15:21:07 EST 2015
    Notes       :
  ----------------------------------------------------------------------*/

define temp-table salesPipeline no-undo
    field category as character
    field amount   as decimal
    index pkCat as primary category 
    .

define temp-table salesActuals no-undo
    field monthAmt as decimal
    field yearAmt  as decimal
    field yearGoal as decimal
    index pkGoal as primary yearGoal
    .

define temp-table topCustomer no-undo
    field fullname as character
    field amount   as decimal
    index pkName as primary fullname
    .

define temp-table topSalesrep no-undo
    field fullname as character
    field amount   as decimal
    index pkName as primary fullname
    .

define temp-table topCall no-undo
    field fullname as character
    field calls    as integer
    index pkName as primary fullname
    .

define dataset dashboardData for salesPipeline, salesActuals, topCustomer, topSalesrep, topCall.
