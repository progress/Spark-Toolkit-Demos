/***************************************************************************\
*****************************************************************************
**
**     Program: wremp.p
**    Descript:
**
*****************************************************************************
\***************************************************************************/

trigger procedure for write of Employee old buffer oldEmployee.

define variable h as integer initial 0.
define variable i as integer initial 0.
define variable j as integer initial 0.
define variable k as integer initial 0.

/* Check to see if the user changed the Employee Number */

if Employee.EmpNum ne oldEmployee.EmpNum and oldEmployee.EmpNum gt 0 then
do:
    /* If user changed the Employee Number, find related benefits and */
    /* change their employee numbers.                                 */
    for each Benefits where Benefits.EmpNum eq oldEmployee.EmpNum:
        Benefits.EmpNum = Employee.EmpNum.
        h = h + 1.
    end.
    if h > 0 then
        message h "benefits changed to reflect the new employee number!"
            view-as alert-box information buttons ok.

    /* If user changed the Employee Number, find related family members and */
    /* change their employee numbers.                                       */
    for each Family where Family.EmpNum eq oldEmployee.EmpNum:
        Family.EmpNum = Employee.EmpNum.
        i = i + 1.
    end.
    if i > 0 then
        message i "family members changed to reflect the new employee number!"
            view-as alert-box information buttons ok.

    /* If user changed the Employee Number, find related timesheet and */
    /* change their employee numbers.                                  */
    for each Timesheet where Employee.EmpNum eq oldEmployee.EmpNum:
        Timesheet.EmpNum = Employee.EmpNum.
        j = j + 1.
    end.
    if j > 0 then
        message j "timesheet changed to reflect the new employee number!"
            view-as alert-box information buttons ok.

    /* If user changed the Employee Number, find related timesheet and */
    /* change their employee numbers.                                  */
    for each Vacation where Vacation.EmpNum eq oldEmployee.EmpNum:
        Vacation.EmpNum = Employee.EmpNum.
        k = k + 1.
    end.
    if k > 0 then
        message k "vacation changed to reflect the new employee number!"
            view-as alert-box information buttons ok.
end.
