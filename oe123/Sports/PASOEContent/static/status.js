/**
 * Copyright (c) 2020-2021 by Progress Software Corporation. All rights reserved.
 *
 * Create an immediately-invoked function expression that returns a static object.
 * This is to be available globally via the variable "app" (aka "window.app").
 */
var app = (function(){
    "use strict";

    /***** Variables / Objects / Overrides *****/


    // Set private flag for application to output messages.
    var useDebugs = false;

    /**
     * Consult the following documentation pages for more information about the proceeding API requests:
     * https://documentation.progress.com/output/ua/OpenEdge_latest/index.html#page/pasoe-admin/transport-management.html#
     * https://documentation.progress.com/output/OpenEdge117/openedge117/#page/pasoe-admin%2Frest-api-reference-for-oemanager.war.html%23
     */

    // WARNING: You should change the default username/password for the oemanager webapp before proceeding with a production site!
    var credentials = "tomcat:tomcat";
    // WARNING: By default this site may be reached by any IP. You are encouraged to set up a limit on who can access the webapp.
    var serverUrl = window.location.protocol + "//" + credentials + "@"
                  + window.location.hostname + (window.location.port ? ":" + window.location.port : "");

    // Append appropriate culture as based on the browser.
    $.getScript("https://kendo.cdn.telerik.com/2020.1.219/js/cultures/kendo.culture." + window.navigator.language + ".min.js")
        .done(function(){
            kendo.culture(window.navigator.language);
        });

    // Append appropriate messages as based on the browser.
    $.getScript("https://kendo.cdn.telerik.com/2020.1.219/js/messages/kendo.messages." + window.navigator.language + ".min.js")
        .done(function(){
            kendo.culture(window.navigator.language);
        });

    // Set defaults for AuthN errors on Kendo DataSource.
    kendo.data.DataSource.prototype.options.error = function(ev){
        if (ev.xhr.status === 401 || ev.xhr.status === 403) {
             console.warn("Your session has expired.");
             app.doLogoutAction();
        }
    };

    /***** Helper Functions *****/

    function logMessage(message, always){
        if ((useDebugs || always) && console && console.log) {
            console.log(message);
        }
    }

    function updateStyles(){
        setTimeout(function(){
            // Convert bootstrap tooltip objects.
            $("[data-toggle=tooltip]").tooltip();
            // Convert bootstrap popover objects.
            $("[data-toggle=popover]").popover();
        }, 100);
    }

    function messageHandler(data){
        if (notify && data && data.messages) {
            $.each(data.messages, function(i, message){
                notify.showMessage(message.messageText, message.messageType);
            });
        }
    }

    function numberWithCommas(number) {
        var parts = number.toString().split(".");
        parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
        return parts.join(".");
    }

    function msToTime(s){
        // Pad to 2 or 3 digits, default is 2
        function pad(n, z) {
            z = z || 2;
            return ('00' + n).slice(-z);
        }
        var ms = s % 1000;
        s = (s - ms) / 1000;
        var secs = s % 60;
        s = (s - secs) / 60;
        var mins = s % 60;
        var hrs = (s - mins) / 60;
        return pad(hrs) + ':' + pad(mins) + ':' + pad(secs) + '.' + pad(ms, 3);
    }

    function isUpperCase(str){
        return str === str.toUpperCase();
    }

    function camelCaseToTitle(str){
        var i = null;
        for (i = str.length - 1; i > 0; i--) {
            if (!isUpperCase(str[i - 1]) && isUpperCase(str[i])) {
                str = str.slice(0, i) + ' ' + str.slice(i);
            }
        }
        return str.charAt(0).toUpperCase() + str.slice(1);
    }

    /***** Application *****/

    var applicationName = null;
    var applicationList = [];
    var fldApplications = null;
    var agentMgrProps = null;
    var sessMgrProps = null;
    var agentList = {};
    var agentCount = 0;
    var agentsReturned = 0;
    var clientSessions = [];
    var serverAccessTime = null;

    var _notificationArea = null;
    function setNotificationArea(selector, options){
        var notificationObj = null; // Notification object instance.
        var el = $(selector);
        if (el.length) {
            // Create a new notification widget.
            notificationObj = el.kendoNotification($.extend({
                appendTo: selector, // Element that anchors all messages.
                autoHideAfter: 30000, // Hide the message after 30 seconds.
                button: true // Display dismissal button in message area.
            }, options)).getKendoNotification();

            // Add a method to display a message and scroll into view.
            notificationObj.showNotification = function(message, type){
                var self = this;
                if (self) {
                    try {
                        // Type is "info" (default), "success", "warning", or "error".
                        if (typeof(message) === "string" && message !== "") {
                            // Single message as string.
                            self.show(message, type || "info");
                        } else if (Array.isArray(message)) {
                            $.each(message, function(i, msg){
                                // Message is an array of strings.
                                if (msg !== "") {
                                    self.show(msg, type || "info");
                                }
                            });
                        }
                        if (self.options && self.options.appendTo) {
                            var container = $(self.options.appendTo);
                            if (container.length) {
                                container.scrollTop(container[0].scrollHeight);
                            }
                        }
                    } catch(e){
                        console.log(e);
                    }
                }
            };
        }
        return notificationObj;
    }

    function initContent(){
        fldApplications = $("#mainHeader input[name=applicationList]").kendoDropDownList({
            dataValueField: "name",
            dataSource: new kendo.data.DataSource(),
            template: "#:name#",
            valueTemplate: "#:name#",
            select: function(e){
                var item = e.item || {};
                var selected = this.dataItem(item.index()) || {};
                if (selected.name) {
                    var server = window.location.protocol + "//" + window.location.hostname + (window.location.port ? ":" + window.location.port : "");
                    window.location = server + window.location.pathname + "?app=" + selected.name;
                    applicationName = selected.name;
                }
            }
        }).getKendoDropDownList();

        $("#tabstrip").kendoTabStrip();

        getApplications(); // Get application information.
    }

    function showMessage(message, type){
        if (!_notificationArea) {
            // Create notification widget as needed, when not present.
            // Override with extra properties as required for application.
            var options = {
                appendTo: null,
                position: {
                    pinned: false,
                    right: 30,
                    top: 50
                },
                stacking: "down",
                width: "30em"
            };
            _notificationArea = setNotificationArea("#notification", options);
        }
        if (_notificationArea) {
            // Add wrapper style around message before display.
            message = '&nbsp;<span style="word-wrap:break-word;white-space:normal;">' + message + '</span>';
            _notificationArea.showNotification(message, type);
        }
    }

    function getApplications(){
        // Get information about all ABL applications for this PAS instance.
        $.ajax({
            contentType: "application/vnd.progress+json",
            dataType: "json",
            url: serverUrl + "/oemanager/applications",
            success: function(data, textStatus, jqXHR){
                // Output OE version info and PAS instance name.
                $("#versionOE").html(data.versionStr || "Unknown OE Version");

                applicationList = (data.result.Application || []);
                if (fldApplications) {
                    fldApplications.dataSource.data(applicationList);
                }
                if (applicationList.length == 0) {
                    showMessage("No applications found", "error");
                    return;
                }

                if (applicationList.length == 1) {
                    applicationName = applicationList[0].name;
                    headerVM.refreshData();
                } else {
                    if ((applicationName || "") == "") {
                        applicationName = applicationList[0].name;
                    } else {
                        // Select the application from the list that matches.
                        $.each(applicationList, function(i, app){
                            if (app.name == applicationName) {
                                fldApplications.select(i);
                            }
                        });
                    }
                    headerVM.refreshData();
                }

                $("#appName").text(applicationName); // Set the name on the screen for the properties tab.
            },
            error: function(jqXHR, textStatus, errorThrown){
                if (jqXHR.status == 401 || jqXHR.status == 403) {
                    console.log("Login Required");
                } else {
                    var errors = null;
                    var errMsg = errorThrown;
                    try {
                        errors = JSON.parse(jqXHR.responseText);
                    }
                    catch(e){}

                    if (errors && errors.operation && errors.outcome && errors.errmsg) {
                        errMsg = errors.operation + " " + errors.outcome + ": " + errors.errmsg;
                    }
                    if (errMsg == "") {
                        errMsg = "Error encountered while executing remote API";
                    }
                    console.log(errMsg);
                    showMessage(errMsg, "error");
                }
            }
        });
    }

    function getSessionProperties(ablApp){
        // Get all SessMgr properties for this ABL application.
        $.ajax({
            contentType: "application/vnd.progress+json",
            dataType: "json",
            url: serverUrl + "/oemanager/applications/" + ablApp + "/properties",
            success: function(data, textStatus, jqXHR){
                sessMgrProps = data.result || {};
                var keys = Object.keys(sessMgrProps).sort();
                $("#sessionMgrInfo").empty();
                $("#sessionMgrInfo").append("<h3>AppServer.SessMgr." + ablApp + "</h3>");
                $.each(keys, function(i, name){
                    if (sessMgrProps[name] !== "" && sessMgrProps[name] !== null) {
                        $("#sessionMgrInfo").append("&nbsp;<b>" + name + "</b>: " + sessMgrProps[name] + "<br/>");
                    }
                });
                $("#sessionMgrInfo").append("<br/>");

                var table = $("<table></table>").attr({cellSpacing: 0, cellPadding: 2});
                var row = $("<tr></tr>");
                var cell1 = $("<td></td>").attr({width: 240}).css("text-align", "right");
                var cell2 = $("<td></td>").attr({width: 100}).css("text-align", "right").css("padding-right", "10px");
                var tmpRow = null;

                tmpRow = row.clone();
                tmpRow.append(cell1.clone().text("Maximum Agents:"));
                tmpRow.append(cell2.clone().text(sessMgrProps.maxAgents || "NA"));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell1.clone().text("Minimum Agents:"));
                tmpRow.append(cell2.clone().text(sessMgrProps.minAgents || "NA"));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell1.clone().text("Initial Agents:"));
                tmpRow.append(cell2.clone().text(sessMgrProps.numInitialAgents || "NA"));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell1.clone().text("Maximum Connections/Agent:"));
                tmpRow.append(cell2.clone().text(sessMgrProps.maxConnectionsPerAgent || "NA"));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell1.clone().text("Maximum ABLSessions/Agent:"));
                tmpRow.append(cell2.clone().text(sessMgrProps.maxABLSessionsPerAgent || "NA"));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell1.clone().text("Idle Connection Timeout:"));
                tmpRow.append(cell2.clone().text(msToTime(sessMgrProps.idleConnectionTimeout || 0)));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell1.clone().text("Idle Session Timeout:"));
                tmpRow.append(cell2.clone().text(msToTime(sessMgrProps.idleSessionTimeout || 0)));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell1.clone().text("Idle Agent Timeout:"));
                tmpRow.append(cell2.clone().text(msToTime(sessMgrProps.idleAgentTimeout || 0)));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell1.clone().text("Idle Resource Timeout:"));
                tmpRow.append(cell2.clone().text(msToTime(sessMgrProps.idleResourceTimeout || 0)));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell1.clone().text("Connection Wait Timeout:"));
                tmpRow.append(cell2.clone().text(msToTime(sessMgrProps.connectionWaitTimeout || 0)));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell1.clone().text("Request Wait Timeout:"));
                tmpRow.append(cell2.clone().text(msToTime(sessMgrProps.requestWaitTimeout || 0)));
                table.append(tmpRow);

                $("#sessionConfig").append(table);

                // Get data which depends on some values from the Session Manager.
                getAgentInfo(ablApp);
                getAppMetrics(ablApp);
            },
            error: function(jqXHR, textStatus, errorThrown){
                if (jqXHR.status == 401 || jqXHR.status == 403) {
                    console.log("Login Required");
                } else {
                    var errors = null;
                    var errMsg = errorThrown;
                    try {
                        errors = JSON.parse(jqXHR.responseText);
                    }
                    catch(e){}

                    if (errors && errors.operation && errors.outcome && errors.errmsg) {
                        errMsg = errors.operation + " " + errors.outcome + ": " + errors.errmsg;
                    }
                    if (errMsg == "") {
                        errMsg = "Error encountered while executing remote API";
                    }
                    console.log(errMsg);
                    showMessage(errMsg, "error");
                }
            }
        });
    }

    function getAgentProperties(ablApp){
        // Get all Agent properties for this ABL application.
        $.ajax({
            contentType: "application/vnd.progress+json",
            dataType: "json",
            url: serverUrl + "/oemanager/applications/" + ablApp + "/agents/properties",
            success: function(data, textStatus, jqXHR){
                agentMgrProps = data.result || {};
                var keys = Object.keys(agentMgrProps).sort();
                $("#agentMgrInfo").empty();
                $("#agentMgrInfo").append("<h3>AppServer.Agent." + ablApp + "</h3>");

                $.each(keys, function(i, name){
                    if (agentMgrProps[name] !== "" && agentMgrProps[name] !== null) {
                        $("#agentMgrInfo").append("&nbsp;<b>" + name + "</b>: " + agentMgrProps[name] + "<br/>");
                    }
                });
                $("#agentMgrInfo").append("<br/>");

                var table = $("<table></table>").attr({cellSpacing: 0, cellPadding: 2});
                var row = $("<tr></tr>");
                var cell1 = $("<td></td>").attr({width: 240}).css("text-align", "right");
                var cell2 = $("<td></td>").attr({width: 100}).css("text-align", "right").css("padding-right", "10px");
                var tmpRow = null;

                tmpRow = row.clone();
                tmpRow.append(cell1.clone().text("Initial Sessions/Agent:"));
                tmpRow.append(cell2.clone().text(agentMgrProps.numInitialSessions || "NA"));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell1.clone().text("Minimum Available Sessions/Agent:"));
                tmpRow.append(cell2.clone().text(agentMgrProps.minAvailableABLSessions || "NA"));
                table.append(tmpRow);

                $("#agentConfig").append(table);
            },
            error: function(jqXHR, textStatus, errorThrown){
                if (jqXHR.status == 401 || jqXHR.status == 403) {
                    console.log("Login Required");
                } else {
                    var errors = null;
                    var errMsg = errorThrown;
                    try {
                        errors = JSON.parse(jqXHR.responseText);
                    }
                    catch(e){}

                    if (errors && errors.operation && errors.outcome && errors.errmsg) {
                        errMsg = errors.operation + " " + errors.outcome + ": " + errors.errmsg;
                    }
                    if (errMsg == "") {
                        errMsg = "Error encountered while executing remote API";
                    }
                    console.log(errMsg);
                    showMessage(errMsg, "error");
                }
            }
        });
    }

    function getAgentInfo(ablApp){
        // Get agent information for this ABL application.
        $.ajax({
            contentType: "application/vnd.progress+json",
            dataType: "json",
            url: serverUrl + "/oemanager/applications/" + ablApp + "/agents",
            success: function(data, textStatus, jqXHR){
                $("#instanceInfo").empty();
                var header = $("<h3></h3>").text("MSAS Agents (" + sessMgrProps.agentExecFile + ")");
                var addAgent = $("<a></a>").css("padding-left", "5px").attr("href", 'javascript:app.startAgent("' + ablApp + '")');
                addAgent.html('<i class="fa fa-plus-square" title="Start new Agent for ' + ablApp + '"></i>');
                header.append(addAgent);
                $("#instanceInfo").append(header);

                var agents = (data.result || {}).agents || [];
                agentCount = agents.length; // Remember how many agents total there are at present.
                if (agentCount > 0) {
                    $.each(agents, function(i, agent){
                        var control = $("<a></a>").css("padding-left", "5px").attr("href", 'javascript:app.killAgent("' + ablApp + '", "' + agent.pid + '")');
                        control.html('<i class="fa fa-stop-circle" title="Stop Agent ' + agent.pid + '"></i>');

                        var span = $("<span></span>").css("line-height", "1.5").css("margin-left", "5px");
                        var info = $("<b></b>").html("Agent PID " + agent.pid + ":&nbsp;" + agent.state + "&nbsp;");
                        span.append(info.append(control)); // Add button to info and append to section span.
                        span.append('<div id="props_' + agent.pid + '"></div>'); // For dynamic session values, when present.
                        span.append('<div id="metrics_' + agent.pid + '"></div>'); // For agent metrics.
                        span.append('<div id="sessions_' + agent.pid + '" class="b-a"></div>'); // For ABL Session data.
                        $("#instanceInfo").append(span).append("<br/>");

                        // Store a list of agent PID's to agent ID's.
                        agentList[agent.agentId] = agent.pid;

                        // Get related information on sessions for this AVAILABLE agent.
                        if (agent.state == "AVAILABLE") {
                            getDynSessions(ablApp, agent.pid);
                            getAgentThreads(ablApp, agent.pid);
                            getAgentMetrics(ablApp, agent.pid);
                        }
                    });
                } else {
                    // Get the client sessions even if no agents are present (an odd case, but still possible if connections linger).
                    getClientSessions(ablApp);
                }
            },
            error: function(jqXHR, textStatus, errorThrown){
                if (jqXHR.status == 401 || jqXHR.status == 403) {
                    console.log("Login Required");
                } else {
                    var errors = null;
                    var errMsg = errorThrown;
                    try {
                        errors = JSON.parse(jqXHR.responseText);
                    }
                    catch(e){}

                    if (errors && errors.operation && errors.outcome && errors.errmsg) {
                        errMsg = errors.operation + " " + errors.outcome + ": " + errors.errmsg;
                    }
                    if (errMsg == "") {
                        errMsg = "Error encountered while executing remote API";
                    }
                    console.log(errMsg);
                    showMessage(errMsg, "error");
                }
            }
        });
    }

    function getDynSessions(ablApp, agentPID){
        // Get dynamic session limits for this agent (OE 12.2+).
        $.ajax({
            contentType: "application/vnd.progress+json",
            dataType: "json",
            url: serverUrl + "/oemanager/applications/" + ablApp + "/agents/" + agentPID + "/dynamicSessionLimit",
            success: function(data, textStatus, jqXHR){
                if (data.result && $("#props_" + agentPID)) {
                    var sessionInfo = (((data.result || {}).AgentSessionInfo || [])[0] || {}).ABLOutput || {};
                    if (sessionInfo) {
                        var table = $("<table></table>").attr({cellSpacing: 0, cellPadding: 2});
                        var row = $("<tr></tr>");
                        var cell = $("<td></td>").attr({width: 120}).css("text-align", "right");
                        var tmpRow = null;

                        tmpRow = row.clone();
                        tmpRow.append(cell.clone().attr({width: 200}).text("Dynamic Max ABL Sessions:"));
                        tmpRow.append(cell.clone().text(numberWithCommas(sessionInfo.dynmaxablsessions || 0)));
                        table.append(tmpRow);

                        tmpRow = row.clone();
                        tmpRow.append(cell.clone().attr({width: 200}).text("Total ABL Sessions:"));
                        tmpRow.append(cell.clone().text(numberWithCommas(sessionInfo.numABLSessions || 0)));
                        table.append(tmpRow);

                        tmpRow = row.clone();
                        tmpRow.append(cell.clone().attr({width: 200}).text("Avail ABL Sessions:"));
                        tmpRow.append(cell.clone().text(numberWithCommas(sessionInfo.numAvailableSessions || 0)));
                        table.append(tmpRow);

                        $("#props_" + agentPID).append(table);
                    }
                }
            },
            error: function(jqXHR, textStatus, errorThrown){
                if (jqXHR.status == 401 || jqXHR.status == 403) {
                    console.log("Login Required");
                } else {
                    // Do not show a message if this API call fails, as it may not exist for earlier versions of OpenEdge.
                }
            }
        });
    }

    function getAgentThreads(ablApp, agentPID){
        // Get threads for this agent.
        $.ajax({
            contentType: "application/vnd.progress+json",
            dataType: "json",
            url: serverUrl + "/oemanager/applications/" + ablApp + "/agents/" + agentPID + "/threads",
            success: function(data, textStatus, jqXHR){
                var threads = (data.result || {}).AgentThread || [];
                if (threads.length > 0 && $("#props_" + agentPID)) {
                    var table = $("<table></table>").attr({cellSpacing: 0, cellPadding: 2});
                    var row = $("<tr></tr>");
                    var cell = $("<td></td>").attr({width: 120}).css("text-align", "right");
                    var tmpRow = null;
                    var started = new Date();
                    var temp = null;

                    $.each(threads, function(i, obj){
                        if (obj.StartTime) {
                            temp = new Date(obj.StartTime.substring(0, 23)); // Only get date+time (no TZ).
                            if (temp < started) {
                                started = temp;
                            }
                        }
                    });

                    tmpRow = row.clone();
                    tmpRow.append(cell.clone().attr({width: 200}).text("Est. Agent Lifetime:"));
                    tmpRow.append(cell.clone().text(msToTime(serverAccessTime.getTime() - started.getTime())).attr("title", "Started: " + kendo.toString(started, "g")));
                    table.append(tmpRow);

                    $("#props_" + agentPID).prepend(table);
                }
            },
            error: function(jqXHR, textStatus, errorThrown){
                if (jqXHR.status == 401 || jqXHR.status == 403) {
                    console.log("Login Required");
                } else {
                    var errors = null;
                    var errMsg = errorThrown;
                    try {
                        errors = JSON.parse(jqXHR.responseText);
                    }
                    catch(e){}

                    if (errors && errors.operation && errors.outcome && errors.errmsg) {
                        errMsg = errors.operation + " " + errors.outcome + ": " + errors.errmsg;
                    }
                    if (errMsg == "") {
                        errMsg = "Error encountered while executing remote API";
                    }
                    console.log(errMsg);
                    showMessage(errMsg, "error");
                }
            }
        });
    }

    function getAgentMetrics(ablApp, agentPID){
        // Get agent information for this ABL application.
        $.ajax({
            contentType: "application/vnd.progress+json",
            dataType: "json",
            url: serverUrl + "/oemanager/applications/" + ablApp + "/agents/" + agentPID + "/metrics",
            success: function(data, textStatus, jqXHR){
                var metrics = (data.result || {}).AgentStatHist || [];
                if (metrics.length > 0 && $("#metrics_" + agentPID)) {
                    var table = $("<table></table>").attr({cellSpacing: 0, cellPadding: 2});
                    var row = $("<tr></tr>");
                    var cell = $("<td></td>").attr({width: 120}).css("text-align", "right");
                    var tmpRow = null;

                    tmpRow = row.clone();
                    tmpRow.append(cell.clone().attr({width: 200}).text("Open Connections:"));
                    tmpRow.append(cell.clone().text(numberWithCommas(metrics[0].OpenConnections || 0)));
                    table.append(tmpRow);

                    tmpRow = row.clone();
                    tmpRow.append(cell.clone().attr({width: 200}).text("Overhead Memory:"));
                    tmpRow.append(cell.clone().text(numberWithCommas(Math.round(parseInt(metrics[0].OverheadMemory || 0) / 1024, 2)) + " KB"));
                    table.append(tmpRow);

                    tmpRow = row.clone();
                    tmpRow.append(cell.clone().attr({width: 200}).text("Approx. Agent Memory:"));
                    tmpRow.append(cell.clone().attr({id: "metrics_" + agentPID + "_memory", value: (metrics[0].OverheadMemory || 0)}).text(""));
                    table.append(tmpRow);

                    $("#metrics_" + agentPID).append(table);
                }

                // Kick off the request for agent sessions.
                getABLSessions(ablApp, agentPID);
            },
            error: function(jqXHR, textStatus, errorThrown){
                if (jqXHR.status == 401 || jqXHR.status == 403) {
                    console.log("Login Required");
                } else {
                    var errors = null;
                    var errMsg = errorThrown;
                    try {
                        errors = JSON.parse(jqXHR.responseText);
                    }
                    catch(e){}

                    if (errors && errors.operation && errors.outcome && errors.errmsg) {
                        errMsg = errors.operation + " " + errors.outcome + ": " + errors.errmsg;
                    }
                    if (errMsg == "") {
                        errMsg = "Error encountered while executing remote API";
                    }
                    console.log(errMsg);
                    showMessage(errMsg, "error");
                }
            }
        });
    }

    function getABLSessions(ablApp, agentPID){
        // Get ABL Session information for this agent PID.
        $.ajax({
            contentType: "application/vnd.progress+json",
            dataType: "json",
            url: serverUrl + "/oemanager/applications/" + ablApp + "/agents/" + agentPID + "/sessions",
            success: function(data, textStatus, jqXHR){
                if ($("#sessions_" + agentPID)) {
                    agentsReturned++; // Increment the counter to indicate we got sessions for another agent.

                    // Run this just after requesting the last of the ABL Sessions, as we need some of that data.
                    if (agentCount == agentsReturned) {
                        getClientSessions(ablApp);
                    }

                    var table = $("<table></table>").attr({cellSpacing: 0, cellPadding: 2});
                    var row = $("<tr></tr>");
                    var head = $("<th></th>").attr({width: 120}).css("text-align", "right");
                    var cell = $("<td></td>").css("text-align", "right");
                    var tmpRow = null;
                    var memTotal = 0;
                    var summary = table.clone(); // For OE11 summary info.

                    tmpRow = row.clone();
                    tmpRow.append(head.clone().html("Session&nbsp;ID"));
                    tmpRow.append(head.clone().text("State"));
                    tmpRow.append(head.clone().text("").attr({width: 30}));
                    tmpRow.append(head.clone().html("Session&nbsp;Started").css("text-align", "left").css("padding-left", "10px").attr({width: 220}));
                    tmpRow.append(head.clone().text("Memory").attr({width: 140}));
                    tmpRow.append(head.clone().html("Bound/Active&nbsp;Session").css("text-align", "left").css("padding-left", "10px").attr({width: 440}));
                    tmpRow.append(head.clone().html("Request ID").css("text-align", "left").attr({width: 160}));
                    table.append(tmpRow);

                    var sessions = (data.result || {}).AgentSession || [];
                    var totalSessions = 0;
                    var availSessions = 0;
                    if ($("#sessions_" + agentPID) && sessions.length > 0) {
                        $.each(sessions, function(i, session){
                            var control = $("<a></a>").css("padding-left", "5px").attr("href", 'javascript:app.killABLSession("' + ablApp + '", "' + agentPID + '", "' + session.SessionId + '")');
                            control.html('<i class="fa fa-stop-circle" title="Terminate ABL Session ' + session.SessionId + '"></i>');

                            tmpRow = row.clone();
                            tmpRow.append(cell.clone().text(session.SessionId).append(control));
                            tmpRow.append(cell.clone().text(session.SessionState));
                            if (session.SessionState == "IDLE") {
                                tmpRow.append(cell.clone());
                                availSessions++;
                            } else {
                                var stacks = $("<a></a>").css("padding-left", "5px").attr("href", 'javascript:app.getSessionStacks("' + ablApp + '", "' + agentPID + '", "' + session.SessionId + '")');
                                stacks.html('<i class="fa fa-sticky-note-o" title="Get Session Stacks"></i>');
                                tmpRow.append(cell.clone().append(stacks));
                            }
                            var started = new Date(session.StartTime.substring(0, 23)); // Only get date+time (no TZ).
                            var lifetime = "Lifetime: " + msToTime(serverAccessTime.getTime() - started.getTime());
                            tmpRow.append(cell.clone().text(session.StartTime).css("text-align", "left").css("padding-left", "10px").attr("title", lifetime));
                            tmpRow.append(cell.clone().text(numberWithCommas(Math.round(parseInt(session.SessionMemory || 0) / 1024, 2)) + " KB"));
                            tmpRow.append(cell.clone().css("text-align", "left").css("padding-left", "10px").attr("id", "bound_sess_" + agentPID + "_" + session.SessionId));
                            tmpRow.append(cell.clone().css("text-align", "left").attr("id", "bound_req_" + agentPID + "_" + session.SessionId));
                            table.append(tmpRow);

                            memTotal += parseInt(session.SessionMemory || 0); // Keep tally of the total memory reported by each session.
                            totalSessions++;
                        });
                        $("#sessions_" + agentPID).append(table);
                    }

                    if ($("#metrics_" + agentPID + "_memory")) {
                        // Update the approximate agent memory with session memory plus overhead.
                        var overhead = parseInt($("#metrics_" + agentPID + "_memory").attr("value"));
                        memTotal += overhead || 0; // Total of agent overhead + session memory.
                        $("#metrics_" + agentPID + "_memory").text(numberWithCommas(Math.round(parseInt(memTotal) / 1024, 2)) + " KB");
                    }

                    // Provide summary data for OpenEdge 11 instances when necessary.
                    var version = data.versionStr || "";
                    if ($("#props_" + agentPID) && version.startsWith("v11")) {
                        tmpRow = row.clone();
                        tmpRow.append(cell.clone().attr({width: 200}).text("Total ABL Sessions:"));
                        tmpRow.append(cell.clone().attr({width: 120}).text(numberWithCommas(totalSessions || 0)));
                        summary.append(tmpRow);

                        tmpRow = row.clone();
                        tmpRow.append(cell.clone().attr({width: 200}).text("Avail ABL Sessions:"));
                        tmpRow.append(cell.clone().attr({width: 120}).text(numberWithCommas(availSessions || 0)));
                        summary.append(tmpRow);

                        tmpRow = row.clone();
                        tmpRow.append(cell.clone().attr({width: 200}).text("Total Session Memory:"));
                        tmpRow.append(cell.clone().attr({width: 120}).text(numberWithCommas(Math.round(parseInt(memTotal) / 1024, 2)) + " KB"));
                        summary.append(tmpRow);

                        $("#props_" + agentPID).append(summary);
                    }
                }
            },
            error: function(jqXHR, textStatus, errorThrown){
                if (jqXHR.status == 401 || jqXHR.status == 403) {
                    console.log("Login Required");
                } else {
                    var errors = null;
                    var errMsg = errorThrown;
                    try {
                        errors = JSON.parse(jqXHR.responseText);
                    }
                    catch(e){}

                    if (errors && errors.operation && errors.outcome && errors.errmsg) {
                        errMsg = errors.operation + " " + errors.outcome + ": " + errors.errmsg;
                    }
                    if (errMsg == "") {
                        errMsg = "Error encountered while executing remote API";
                    }
                    console.log(errMsg);
                    showMessage(errMsg, "error");
                }
            }
        });
    }

    function getClientSessions(ablApp){
        // Get client HTTP sessions for this ABL application.
        $.ajax({
            contentType: "application/vnd.progress+json",
            dataType: "json",
            url: serverUrl + "/oemanager/applications/" + ablApp + "/sessions",
            success: function(data, textStatus, jqXHR){
                clientSessions = (data.result || {}).OEABLSession || [];

                $("#sessionInfo").empty();
                $("#sessionInfo").append('<b>Total Sessions:</b> <span id="totalSessions">' + clientSessions.length + '</span>&nbsp;');
                var closeAll = $("<a></a>").css("padding-right", "5px").attr("href", 'javascript:app.killAllClientSessions()');
                closeAll.html('<i class="fa fa-stop-circle" title="Terminate All Client Sessions"></i>');
                $("#sessionInfo").append(closeAll);
                $("#sessionInfo").append('<a href="/manager/" target="_blank" style="float:right">[Go to Tomcat Manager]</a>');
                $("#sessionInfo").append("<br/><br/>");

                var table = $("<table></table>").attr({cellSpacing: 0, cellPadding: 2}).css("border", "1px solid #DEDEDE");
                var row = $("<tr></tr>");
                var head = $("<th></th>").attr({width: 120}).css("text-align", "left");
                var cell = $("<td></td>").attr({width: 80});
                var tmpRow = null;

                tmpRow = row.clone();
                tmpRow.append(head.clone().text("Rq. State"));
                tmpRow.append(head.clone().text("Session State").attr({width: 120}));
                tmpRow.append(head.clone().text("Bound")).attr({width: 60});
                tmpRow.append(head.clone().text("Last Access / Started").attr({width: 240}));
                tmpRow.append(head.clone().text("Elapsed Time").attr({width: 120}));
                tmpRow.append(head.clone().text("Session Model").attr({width: 160}));
                tmpRow.append(head.clone().text("Adapter"));
                tmpRow.append(head.clone().text("Session ID").attr({width: 500}));
                tmpRow.append(head.clone().text("Request ID").attr({width: 140}));
                table.append(tmpRow);

                $.each(clientSessions, function(i, session){
                    var control = $("<a></a>").css("padding-right", "5px").attr("href", 'javascript:app.killClientSession("' + ablApp + '", "' + session.sessionID + '")');
                    control.html('<i class="fa fa-stop-circle" title="Terminate Client Session ' + session.sessionID + '"></i>');
                    var sessionClassID = ("clSess_" + session.sessionID || "").replace(".", "_").replace("-", "_");

                    tmpRow = row.clone().attr("class", sessionClassID).css("border-top", "1px solid #DEDEDE");
                    tmpRow.append(cell.clone().text(session.requestState || "NA"));
                    tmpRow.append(cell.clone().text(session.sessionState || "NA"));
                    tmpRow.append(cell.clone().text(session.bound ? "Yes" : "No"));
                    tmpRow.append(cell.clone().text(session.lastAccessStr || "NA"));
                    tmpRow.append(cell.clone().text(msToTime(session.elapsedTimeMs || 0)));
                    tmpRow.append(cell.clone().text(session.sessionType || "NA"));
                    tmpRow.append(cell.clone().text(session.adapterType || "NA"));
                    tmpRow.append(cell.clone().text(session.sessionID || "").prepend(control));
                    tmpRow.append(cell.clone().text(session.requestID || ""));
                    table.append(tmpRow);

                    var boundString = ""; // Clear on each iteration of the sessions.
                    if (session.bound && session.agentID && session.ablSessionID) {
                        // Set a default value for the bound string info.
                        boundString = "[PID Unavailable] #" + session.ablSessionID;

                        if (agentList[session.agentID]) {
                            // Set up a string with known PID plus the ABL Session ID.
                            boundString = agentList[session.agentID] + " #" + session.ablSessionID;

                            // Update the agent-session if we match an ID present in the HTML.
                            var boundSessID = "#bound_sess_" + agentList[session.agentID] + "_" + session.ablSessionID;
                            if ($(boundSessID)) {
                                $(boundSessID).text(session.sessionID || "");
                            }
                            var boundReqID = "#bound_req_" + agentList[session.agentID] + "_" + session.ablSessionID;
                            if ($(boundReqID)) {
                                $(boundReqID).text(session.requestID || "");
                            }
                        }
                    }

                    if (session.clientConnInfo) {
                        tmpRow = row.clone().attr("class", sessionClassID).css("background-color", "#F0F0F0");
                        tmpRow.append(cell.clone().text("Client Connection: " + (session.clientConnInfo.clientName || "NA")).css("padding-left", "20px").attr({colspan: 3}));
                        tmpRow.append(cell.clone().text(session.clientConnInfo.reqStartTimeStr || "NA"));
                        tmpRow.append(cell.clone().text(msToTime(session.clientConnInfo.elapsedTimeMs || 0)));

                        if (session.clientConnInfo.requestProcedure) {
                            tmpRow.append(cell.clone().text(session.clientConnInfo.requestProcedure).attr({colspan: 2}));
                        } else {
                            tmpRow.append(cell.clone().attr({colspan: 2}));
                        }

                        if (boundString != "") {
                            tmpRow.append(cell.clone().text("Agent-Session: " + boundString).attr({colspan: 2}));
                        } else {
                            tmpRow.append(cell.clone().attr({colspan: 2}));
                        }
                        table.append(tmpRow);
                    }

                    if (session.agentConnInfo) {
                        tmpRow = row.clone().attr("class", sessionClassID).css("background-color", "#EEEEEE");

                        if (agentList[session.agentConnInfo.agentID]) {
                            tmpRow.append(cell.clone().text("Agent Connection: PID " + agentList[session.agentConnInfo.agentID]).css("padding-left", "20px").attr({colspan: 4}));
                        } else {
                            tmpRow.append(cell.clone().text("Agent Connection: ID " + (session.agentConnInfo.agentID || "NA")).css("padding-left", "20px").attr({colspan: 4}));
                        }

                        tmpRow.append(cell.clone().text(session.agentConnInfo.state || "NA"));
                        tmpRow.append(cell.clone().text("Agent: " + session.agentConnInfo.agentAddr || "NA").attr({colspan: 2}));
                        tmpRow.append(cell.clone().text("Local: " + session.agentConnInfo.localAddr || "NA").attr({colspan: 2}));
                        table.append(tmpRow);
                    }
                });

                $("#sessionInfo").append(table);
            },
            error: function(jqXHR, textStatus, errorThrown){
                if (jqXHR.status == 401 || jqXHR.status == 403) {
                    console.log("Login Required");
                } else {
                    var errors = null;
                    var errMsg = errorThrown;
                    try {
                        errors = JSON.parse(jqXHR.responseText);
                    }
                    catch(e){}

                    if (errors && errors.operation && errors.outcome && errors.errmsg) {
                        errMsg = errors.operation + " " + errors.outcome + ": " + errors.errmsg;
                    }
                    if (errMsg == "") {
                        errMsg = "Error encountered while executing remote API";
                    }
                    console.log(errMsg);
                    showMessage(errMsg, "error");
                }
            }
        });
    }

    function getAppMetrics(ablApp){
        // Get metrics for this ABL application.
        $.ajax({
            contentType: "application/vnd.progress+json",
            dataType: "json",
            url: serverUrl + "/oemanager/applications/" + ablApp + "/metrics",
            success: function(data, textStatus, jqXHR){
                // Save the metrics in case we want this data later.
                var metrics = data.result || {};

                var collectType = "Not Enabled";
                if (sessMgrProps.collectMetrics) {
                    switch(sessMgrProps.collectMetrics){
                        case "1":
                            collectType = "Count-Based";
                            break;
                        case "2":
                            collectType = "Time-Based";
                            break;
                        case "3":
                            collectType = "Count+Time";
                            break;
                    }
                }

                // Reset the metrics area and prepare a new header with data in a table.
                $("#metricsInfo").empty();
                var header = $("<h3></h3>").text("Session Manager Metrics (" + collectType + ")");
                $("#metricsInfo").append(header);

                var table = $("<table></table>").attr({cellSpacing: 0, cellPadding: 2}).attr("class", "b-a");
                var row = $("<tr></tr>");
                var cell = $("<td></td>").attr({width: 240}).css("text-align", "right").css("padding-right", "10px");
                var tmpRow = null;

                if (metrics.accessTime && metrics.accessTime != "") {
                    serverAccessTime = new Date(metrics.accessTime.substring(0, 23)); // Only get date+time (no TZ).
                }

                tmpRow = row.clone();
                tmpRow.append(cell.clone().text("# Requests to Session:"));
                tmpRow.append(cell.clone().text(numberWithCommas(metrics.requests || 0)));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell.clone().text("# Agent Responses Read:"));
                tmpRow.append(cell.clone().text(numberWithCommas(metrics.reads || 0) + " (" + numberWithCommas(metrics.readErrors || 0) + " Errors)"));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell.clone().text("Agent Read Time (Mn, Mx, Av):"));
                tmpRow.append(cell.clone().text(numberWithCommas((metrics.minAgentReadTime || 0) / 1000) + " s / "
                                               + numberWithCommas((metrics.maxAgentReadTime || 0) / 1000) + " s / "
                                               + numberWithCommas((metrics.avgAgentReadTime || 0) / 1000)  + " s"));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell.clone().text("# Agent Requests Written:"));
                tmpRow.append(cell.clone().text(numberWithCommas(metrics.writes || 0) + " (" + numberWithCommas(metrics.writeErrors || 0) + " Errors)"));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell.clone().text("Concurrent Connected Clients:"));
                tmpRow.append(cell.clone().text(numberWithCommas(metrics.concurrentConnectedClients)
                                               + " (Max: " + numberWithCommas(metrics.maxConcurrentClients || 0) + ")"));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell.clone().text("Total Reserve ABLSession Wait:"));
                tmpRow.append(cell.clone().text(msToTime(metrics.totReserveABLSessionWaitTime || 0)));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell.clone().text("# Reserve ABLSession Waits:"));
                tmpRow.append(cell.clone().text(numberWithCommas(metrics.numReserveABLSessionWaits || 0)));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell.clone().text("Avg. Reserve ABLSession Wait:"));
                tmpRow.append(cell.clone().text(msToTime(metrics.avgReserveABLSessionWaitTime || 0)));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell.clone().text("Max. Reserve ABLSession Wait:"));
                tmpRow.append(cell.clone().text(msToTime(metrics.maxReserveABLSessionWaitTime || 0)));
                table.append(tmpRow);

                tmpRow = row.clone();
                tmpRow.append(cell.clone().text("# Reserve ABLSession Timeout:"));
                tmpRow.append(cell.clone().text(numberWithCommas(metrics.numReserveABLSessionTimeouts || 0)));
                table.append(tmpRow);

                $("#metricsInfo").append(table);
            },
            error: function(jqXHR, textStatus, errorThrown){
                if (jqXHR.status == 401 || jqXHR.status == 403) {
                    console.log("Login Required");
                } else {
                    var errors = null;
                    var errMsg = errorThrown;
                    try {
                        errors = JSON.parse(jqXHR.responseText);
                    }
                    catch(e){}

                    if (errors && errors.operation && errors.outcome && errors.errmsg) {
                        errMsg = errors.operation + " " + errors.outcome + ": " + errors.errmsg;
                    }
                    if (errMsg == "") {
                        errMsg = "Error encountered while executing remote API";
                    }
                    console.log(errMsg);
                    showMessage(errMsg, "error");
                }
            }
        });
    }

    function killAgent(ablApp, agentPID){
        // Kill a particular session.
        if (ablApp && agentPID && confirm("Are you sure you wish to stop agent " + agentPID + "?")) {
            $.ajax({
                contentType: "application/vnd.progress+json",
                dataType: "json",
                method: "delete",
                url: serverUrl + "/oemanager/applications/" + ablApp + "/agents/" + agentPID,
                success: function(data, textStatus, jqXHR){
                    showMessage(data.outcome + ": Stopped Agent PID: " + agentPID + ".", "success");
                    headerVM.refreshData();
                },
                error: function(jqXHR, textStatus, errorThrown){
                    if (jqXHR.status == 401 || jqXHR.status == 403) {
                        console.log("Login Required");
                    } else {
                        var errors = null;
                        var errMsg = errorThrown;
                        try {
                            errors = JSON.parse(jqXHR.responseText);
                        }
                        catch(e){}

                        if (errors && errors.operation && errors.outcome && errors.errmsg) {
                            errMsg = errors.operation + " " + errors.outcome + ": " + errors.errmsg + " (" + agentPID + ")";
                        }
                        if (errMsg == "") {
                            errMsg = "Error encountered while executing remote API";
                        }
                        console.log(errMsg);
                        showMessage(errMsg, "error");
                    }
                }
            });
        }
    }

    function killABLSession(ablApp, agentPID, sessionID){
        // Kill a particular ABL Session.
        if (ablApp && sessionID && confirm("Are you sure you wish to trim ABL Session " + agentPID + " #" + sessionID + "?")) {
            // A terminateOpt value of 0 causes a graceful termination and a value of 1 causes a forced termination.
            $.ajax({
                contentType: "application/vnd.progress+json",
                dataType: "json",
                method: "delete",
                url: serverUrl + "/oemanager/applications/" + ablApp + "/agents/" + agentPID + "/sessions/" + sessionID + "?terminateOpt=1",
                success: function(data, textStatus, jqXHR){
                    showMessage(data.outcome + ": Stopped ABL Session: " + sessionID + ".", "success");
                    headerVM.refreshData();
                },
                error: function(jqXHR, textStatus, errorThrown){
                    if (jqXHR.status == 401 || jqXHR.status == 403) {
                        console.log("Login Required");
                    } else {
                        var errors = null;
                        var errMsg = errorThrown;
                        try {
                            errors = JSON.parse(jqXHR.responseText);
                        }
                        catch(e){}

                        if (errors && errors.operation && errors.outcome && errors.errmsg) {
                            errMsg = errors.operation + " " + errors.outcome + ": " + errors.errmsg + " (" + agentPID + " #" + sessionID + ")";
                        }
                        if (errMsg == "") {
                            errMsg = "Error encountered while executing remote API";
                        }
                        console.log(errMsg);
                        showMessage(errMsg, "error");
                    }
                }
            });
        }
    }

    function killClientSession(ablApp, sessionID){
        // Kill a particular client HTTP session.
        if (ablApp && sessionID && confirm("Are you sure you wish to close client session " + sessionID + "?")) {
            // A terminateOpt value of 0 causes a graceful termination and a value of 1 causes a forced termination.
            $.ajax({
                contentType: "application/vnd.progress+json",
                dataType: "json",
                method: "delete",
                url: serverUrl + "/oemanager/applications/" + ablApp + "/sessions" + "?terminateOpt=1&sessionID=" + sessionID,
                success: function(data, textStatus, jqXHR){
                    showMessage(data.outcome + ": Stopped Client Session: " + sessionID + ".", "success");
                    headerVM.refreshData();
                },
                error: function(jqXHR, textStatus, errorThrown){
                    if (jqXHR.status == 401 || jqXHR.status == 403) {
                        console.log("Login Required");
                    } else {
                        var errors = null;
                        var errMsg = errorThrown;
                        try {
                            errors = JSON.parse(jqXHR.responseText);
                        }
                        catch(e){}

                        if (errors && errors.operation && errors.outcome && errors.errmsg) {
                            errMsg = errors.operation + " " + errors.outcome + ": " + errors.errmsg + " (" + sessionID + ")";
                        }
                        if (errMsg == "") {
                            errMsg = "Error encountered while executing remote API";
                        }
                        console.log(errMsg);
                        showMessage(errMsg, "error");
                    }
                }
            });
        }
    }


    function killAllClientSessions(){
        // Uses the last list of known HTTP sessions and terminates each one.
        if (clientSessions.length > 0 && confirm("Are you sure you wish to close ALL client sessions?")) {
            var removedClientSessions = [];
            var failedClientSessions = [];
            var totalClientSessions = clientSessions.length;

            showMessage("Closing Client Sessions...", "success");

            $.each(clientSessions, function(i, session){
                // A terminateOpt value of 0 causes a graceful termination and a value of 1 causes a forced termination.
                $.ajax({
                    contentType: "application/vnd.progress+json",
                    dataType: "json",
                    method: "delete",
                    url: serverUrl + "/oemanager/applications/" + applicationName + "/sessions" + "?terminateOpt=1&sessionID=" + session.sessionID,
                    success: function(data, textStatus, jqXHR){
                        removedClientSessions.push(session); // Keep up with a list of terminated sessions.

                        // Remove the client session from the screen after a successful termination.
                        var sessionClassID = ("clSess_" + session.sessionID).replace(".", "_").replace("-", "_");
                        if ($("." + sessionClassID)) {
                            $("." + sessionClassID).empty();
                        }

                        // If all sessions are accounted for, do something with the screen to reflect changes.
                        if ((removedClientSessions.length + failedClientSessions.length) == totalClientSessions) {
                            // Update the total based on any remaining client sessions.
                            $("#totalSessions").text(failedClientSessions.length);

                            // Refresh the list of client sessions with failed terminations.
                            clientSessions = failedClientSessions;

                            headerVM.refreshData(); // Refresh all data to remain in sync.
                        }
                    },
                    error: function(jqXHR, textStatus, errorThrown){
                        failedClientSessions.push(session); // Keep up with a list of failed terminations.

                        if (jqXHR.status == 401 || jqXHR.status == 403) {
                            console.log("Login Required");
                        } else {
                            var errors = null;
                            var errMsg = errorThrown;
                            try {
                                errors = JSON.parse(jqXHR.responseText);
                            }
                            catch(e){}

                            if (errors && errors.operation && errors.outcome && errors.errmsg) {
                                errMsg = errors.operation + " " + errors.outcome + ": " + errors.errmsg + ": " + session.sessionID;
                            }
                            if (errMsg == "") {
                                errMsg = "Error encountered while executing remote API";
                            }
                            console.log(errMsg);
                            showMessage(errMsg, "error");
                        }

                        // If all sessions are accounted for, do something with the screen to reflect changes.
                        if ((removedClientSessions.length + failedClientSessions.length) == totalClientSessions) {
                            // Update the total based on any remaining client sessions.
                            $("#totalSessions").text(failedClientSessions.length);

                            // Refresh the list of client sessions with failed terminations.
                            clientSessions = failedClientSessions;

                            headerVM.refreshData(); // Refresh all data to remain in sync.
                        }
                    }
                });
            });
        }
    }

    function startAgent(ablApp){
        // Kill a particular session.
        if (ablApp && confirm("Start a new agent for " + ablApp + "?")) {
            $.ajax({
                contentType: "application/vnd.progress+json",
                dataType: "json",
                method: "post",
                url: serverUrl + "/oemanager/applications/" + ablApp + "/addAgent",
                success: function(data, textStatus, jqXHR){
                    showMessage(data.outcome + ": Starting Agent for " + ablApp + ".", "success");
                    headerVM.refreshData();
                },
                error: function(jqXHR, textStatus, errorThrown){
                    if (jqXHR.status == 401 || jqXHR.status == 403) {
                        console.log("Login Required");
                    } else {
                        var errors = null;
                        var errMsg = errorThrown;
                        try {
                            errors = JSON.parse(jqXHR.responseText);
                        }
                        catch(e){}

                        if (errors && errors.operation && errors.outcome && errors.errmsg) {
                            errMsg = errors.operation + " " + errors.outcome + ": " + errors.errmsg + " (" + ablApp + ")";
                        }
                        if (errMsg == "") {
                            errMsg = "Error encountered while executing remote API";
                        }
                        console.log(errMsg);
                        showMessage(errMsg, "error");
                    }
                }
            });
        }
    }

    function getSessionStacks(ablApp, agentPID, sessionID){
        // Obtain stack information for a specific agent and session.
        if (ablApp && sessionID) {
            $.ajax({
                contentType: "application/vnd.progress+json",
                dataType: "json",
                method: "get",
                url: serverUrl + "/oemanager/applications/" + ablApp + "/agents/" + agentPID + "/sessions/" + sessionID + "/stacks",
                success: function(data, textStatus, jqXHR){
                    if (data.result && data.result.ABLStacks) {
                        var stacks = (data.result.ABLStacks || [])[0] || {};
                        /*
                        var callStack = stacks.Callstack || [];
                        var databases = stacks.Databases || [];
                        var oo4GlObjs = stacks.OO4GLObjs || [];
                        var persProcs = stacks.PersProcs || [];
                        */
                        saveAsFile(JSON.stringify(stacks, null, 4), ablApp + "_" + agentPID + "_" + sessionID + "_Stacks.json");
                    }
                },
                error: function(jqXHR, textStatus, errorThrown){
                    if (jqXHR.status == 401 || jqXHR.status == 403) {
                        console.log("Login Required");
                    } else {
                        var errors = null;
                        var errMsg = errorThrown;
                        try {
                            errors = JSON.parse(jqXHR.responseText);
                        }
                        catch(e){}

                        if (errors && errors.operation && errors.outcome && errors.errmsg) {
                            errMsg = errors.operation + " " + errors.outcome + ": " + errors.errmsg + " (" + agentPID + " #" + sessionID + ")";
                        }
                        if (errMsg == "") {
                            errMsg = "Error encountered while executing remote API";
                        }
                        console.log(errMsg);
                        showMessage(errMsg, "error");
                    }
                }
            });
        }
    }

    function getTransportMetrics(ablApp, webApp, transport){
        // Obtain metrics for a transport of a webapp.
        if (ablApp && webApp && transport) {
            transport = transport.toLowerCase();
            $.ajax({
                contentType: "application/vnd.progress+json",
                dataType: "json",
                method: "get",
                url: serverUrl + "/oemanager/applications/" + ablApp + "/webapps/" + webApp + "/transports/" + transport + "/metrics",
                success: function(data, textStatus, jqXHR){
                    if (data.result) {
                        if ($("#" + webApp + "_metrics")) {
                            var table = $("<table></table>").attr({cellSpacing: 0, cellPadding: 2});
                            var row = $("<tr></tr>");
                            var cell1 = $("<td></td>").attr({width: 200}).css("text-align", "right");
                            var cell2 = $("<td></td>").attr({width: 220}).css("text-align", "right");
                            var tmpRow = row.clone();

                            $("#" + webApp + "_metrics").empty();
                            tmpRow.append(cell1.clone().attr("colspan", 2).css("text-align", "center").html("<h4>" + ablApp + "." + webApp + "." + transport + " Metrics</h4>"));
                            table.append(tmpRow);

                            $.each(data.result, function(name, value){
                                tmpRow = row.clone();
                                tmpRow.append(cell1.clone().text(camelCaseToTitle(name) + ":"));
                                tmpRow.append(cell2.clone().text(isNaN(value) ? value : numberWithCommas(value)));
                                table.append(tmpRow);
                            });
                            $("#" + webApp + "_metrics").append(table);
                        }
                    }
                },
                error: function(jqXHR, textStatus, errorThrown){
                    if (jqXHR.status == 401 || jqXHR.status == 403) {
                        console.log("Login Required");
                    } else {
                        var errors = null;
                        var errMsg = errorThrown;
                        try {
                            errors = JSON.parse(jqXHR.responseText);
                        }
                        catch(e){}

                        if (errors && errors.operation && errors.outcome && errors.errmsg) {
                            errMsg = errors.operation + " " + errors.outcome + ": " + errors.errmsg + " (" + agentPID + " #" + sessionID + ")";
                        }
                        if (errMsg == "") {
                            errMsg = "Error encountered while executing remote API";
                        }
                        console.log(errMsg);
                        showMessage(errMsg, "error");
                    }
                }
            });
        }
    }

    function saveAsFile(textToWrite, filename) {
        var textFileAsBlob = new Blob([textToWrite], {type: "text/plain"});
        var downloadLink = document.createElement("a");
        downloadLink.download = filename;
        downloadLink.innerHTML = "Download File";
        if (window.webkitURL != null) {
            // Chrome allows the link to be clicked without actually adding it to the DOM.
            downloadLink.href = window.webkitURL.createObjectURL(textFileAsBlob);
        } else {
            // Firefox requires the link to be added to the DOM before it can be clicked.
            downloadLink.href = window.URL.createObjectURL(textFileAsBlob);
            downloadLink.onclick = function(event){
                // Remove the link from the DOM.
                document.body.removeChild(event.target);
            };
            downloadLink.style.display = "none";
            document.body.appendChild(downloadLink);
        }
        downloadLink.click();
    }

    function refreshWebApps() {
        $.each(applicationList, function(i, ablApp){
            // Make sure certain areas are emptied.
            $("#webappInfo").empty();

            if (ablApp.name == applicationName) {
                // Output information about the current ABL application.
                var transportInfo = "";
                var webApps = ablApp.webapps || [];

                $.each(webApps, function(i, webApp){
                    // Display the name of this ABL app and any available transports.
                    $("#webappInfo").append("<h3>" + webApp.applicationName + "." + webApp.name + "</h3>");
                    $.each(webApp.transports, function(j, transport){
                        if (transport.state === "ENABLED") {
                            // Show a green box for enabled transports, and allow clicking the item to show metrics.
                            transportInfo = $("<a></a>").css("padding-left", "5px").attr("href", 'javascript:app.getTransportMetrics("' + ablApp.name + '", "' + webApp.name + '", "' + transport.name + '")');
                            transportInfo.html('<span class="btn btn-success" title="' + transport.description + '">' + transport.name + ' ' + transport.version + '</span>');
                        } else {
                            // Show a red box for disabled transports, and clicking the item does nothing.
                            transportInfo = $("<a></a>").css("padding-left", "5px").attr("href", 'javascript:void(0)');
                            transportInfo.html('<span class="btn btn-danger" title="' + transport.description + '">' + transport.name + ' ' + transport.version + '</span>');
                        }
                        $("#webappInfo").append(transportInfo);
                    });
                    var metrics = $("<div></div>").css("margin", "5px").css("padding-left", "5px").attr("id", webApp.name + "_metrics");
                    $("#webappInfo").append(metrics);
                    $("#webappInfo").append("<br/><br/>");
                });
            }
        });
    }

    /***** Initialization *****/

    // Create a VM to be used by the header.
    var headerVM = kendo.observable({
        headerTitle: "ABL Application",
        refreshData: function(){
            $.each(applicationList, function(i, ablApp){
                // Make sure certain areas are emptied.
                $("#sessionInfo").empty();
                $("#sessionConfig").empty();
                $("#agentConfig").empty();

                // Update the time of last refresh.
                $("#lastRun").html(new Date());

                // Reset some global variables.
                agentMgrProps = null;
                sessMgrProps = null;
                agentList = {};
                agentCount = 0;
                agentsReturned = 0;
                clientSessions = [];

                // Display webapp transports with metrics.
                refreshWebApps();
            });

            // Get properties of the current ABL app.
            getSessionProperties(applicationName);
            getAgentProperties(applicationName);
        }
    });

    // Create a VM to be used by the content.
    var contentVM = kendo.observable({});

    $(document).ready(function(){
        if (window.location.search != "") {
            var urlParams = new URLSearchParams(window.location.search);
            applicationName = urlParams.get("app");
        }

        // Load current culture.
        kendo.culture(window.navigator.language);

        kendo.bind($("#mainHeader"), headerVM); // Bind VM to header.
        kendo.bind($("#mainContent"), contentVM); // Bind VM to content.

        updateStyles(); // Load any default styles.
        initContent(); // Create content widgets.
    });

    /***** Public Object *****/

    return {
        killAgent: killAgent,
        killABLSession: killABLSession,
        killClientSession: killClientSession,
        killAllClientSessions: killAllClientSessions,
        startAgent: startAgent,
        getSessionStacks: getSessionStacks,
        getTransportMetrics: getTransportMetrics,
        showMessage: showMessage
    };

})();