var CustomerUpdGridSPACtrl = (function(){
    "use strict";

    var resourceName = "customer";
    var searchField1 = "CustName";
    var searchOper1 = "startswith";
    var datasetName = "dsCustomer";
    var tableName = "ttCustomer";
    var gridName = "MasterGrid";
    var viewName = "#CustomerUpdGridSPAView";
    var searchOnLoad = true;
    var viewStateJSDO = null;
    var viewStateID = null;
    var viewState = null;

    var primaryVM = kendo.observable({
        context: {},
        params: {
            searchValue: ""
        },
        clearErrors: function(){
            var validator = spark.form.getValidator(viewName + " form[name=searchForm]");
            if (validator) {
                validator.hideMessages();
            }
        },
        doSearch: function(ev){
            if (spark.form.validate(viewName + " form[name=searchForm]")) {
                var params = this.toJSON().params || {};
                var filter = []; // Add default options here.
                var columnFilter = getDataSource().filter() || null;
                if (columnFilter) {
                    $.each(columnFilter.filters, function(i, criteria){
                        if (criteria.field === searchField1) {
                            if ((params.searchValue || "") === "") {
                                // On-screen field is blank, so skip criteria.
                            }
                        } else {
                            // Add all other column filters to the array.
                            filter.push(criteria);
                        }
                    });
                }
                if ((params.searchValue || "") !== "") {
                    // Add main search field if value is non-blank.
                    filter.push({
                        field: searchField1,
                        operator: searchOper1,
                        value: params.searchValue
                    });
                }
                getDataSource().filter({logic: "and", filters: filter});
            }
        }
    });

    function fetchViewState(){
        var promise = $.Deferred();
        var query = {
            client: "KendoUI",
            filter: {
                logic: "and",
                filters: [{
                    field: "ContextType",
                    operator: "equals",
                    value: "grid"
                }, {
                    field: "ContextViewID",
                    operator: "equals",
                    value: viewName
                }, {
                    field: "ContextTitle",
                    operator: "equals",
                    value: gridName
                }, {
                    field: "ContextSeqNo",
                    operator: "equals",
                    value: 1
                }]
            }
        };

        viewStateJSDO.fill(JSON.stringify(query))
            .then(function(jsdo, result, request){
                var dsWebContext = (request.response || {}).dsWebContext || {};
                var ttWebContext = (dsWebContext.ttWebContext || [])[0] || {};
                var myViewState = ttWebContext.ContextData || ""; // Get stringified data.
                myViewState = myViewState !== "" ? JSON.parse(myViewState.replace(/\\\"/g, "\"")) : {};
                promise.resolve(ttWebContext._id || null, myViewState);
            }, function() {
                promise.resolve(null, {});
            });

        return promise;
    }

    function saveViewState(){
        var promise = $.Deferred();

        var grid = $(viewName + " div[name=" + gridName + "]").data("kendoGrid");
        viewState = spark.grid.getViewState(grid);

        // Locate the context record for this view's primary grid.
        var jsrecord = viewStateJSDO.findById(viewStateID);
        if (jsrecord) {
            // Modify and save the currently-available record.
            jsrecord.ContextData = JSON.stringify(viewState);
            viewStateJSDO.assign(jsrecord);
        } else {
            // Otherwise create a new context record.
            jsrecord = {
                ContextType: "grid",
                ContextViewID: viewName,
                ContextTitle: gridName,
                ContextSeqNo: 1,
                ContextData: JSON.stringify(viewState)
            };
            viewStateJSDO.add(jsrecord);
        }
        viewStateJSDO.saveChanges(true)
            .always(function(){
                promise.resolve();
            });

        return promise;
    }

    var _primaryDS = null;
    function getDataSource(){
        if (!_primaryDS) {
            _primaryDS = spark.createJSDODataSource(resourceName, {
                pageSize: 20,
                filter: (viewState && viewState.filter) ? viewState.filter : null,
                group: (viewState && viewState.group) ? viewState.group : [],
                sort: (viewState && viewState.sort) ? viewState.sort : {field: searchField1, dir: "asc"},
                tableRef: tableName,
                onBeforeFill: function(jsdo, request){
                    // Add context to the filter parameter in the request.
                    if (request.objParam) {
                        var data = JSON.parse(request.objParam.filter || "{}");
                        var context = primaryVM.toJSON().context;
                        data.context = context || {};
                        request.objParam.filter = JSON.stringify(data);
                    }
                },
                onAfterSaveChanges: function(jsdo, success, request){
                    if (success && request.operation === progress.data.JSDO._OP_SUBMIT) {
                        // Obtain information about submit operation that just occurred.
                        var data = (((request || {}).response[datasetName] || {})[tableName] || [])[0] || null;
                        if (data) {
                            // Perform a search (refresh) when search field is found in results.
                            primaryVM.set("params.searchValue", data[searchField1] || "");
                            primaryVM.doSearch();
                        }
                    }

                    // Parse the result for any possible messages.
                    var response = request.response;
                    if (spark.notify.responseHasInfo(response) || spark.notify.responseHasErrors(response)) {
                        app.showMessages(response);
                    }
                }
            });
        }
        return _primaryDS;
    }

    function showGrid(){
        var gridColumns = [{
            field: "CustNum",
            attributes: {class: "numbers"},
            template: "#=kendo.toString(CustNum, 'n0')#",
            title: "Cust\#",
            width: 120
        }, {
            field: "CustName",
            title: "Customer Name",
            width: 150
        }, {
            field: "Address",
            title: "Address",
            width: 150
        }, {
            field: "Address2",
            hidden: true,
            title: "Address2",
            width: 150
        }, {
            field: "City",
            title: "City",
            width: 150
        }, {
            field: "State",
            title: "State/Province",
            width: 150,
            editor: function(container, options){
                // Create the field params using some grid information (like the Country value).
                var fieldOptions = {
                    autoBind: true,
                    dataTextField: "FullName",
                    dataValueField: "Abbrev",
                    invokeResource: "locality",
                    invokeMethod: "stateProvince",
                    invokeDataProperty: "states",
                    params: {country: options.model.Country},
                    dataBound: function(ev){
                        var data = options.model[options.field] || options.model.defaults[options.field];
                        ev.sender.value(data);
                    }
                };
                // Create the function (with field params) to create the editor (with grid params).
                return (spark.grid.createInvokeLookupEditor(fieldOptions))(container, options);
            }
        }, {
            field: "PostalCode",
            title: "Postal Code",
            width: 150
        }, {
            field: "Country",
            title: "Country",
            width: 150,
            editor: spark.grid.createSimpleLookupEditor({dataSource: ["USA", "Canada"]})
        }, {
            field: "Contact",
            hidden: true,
            title: "Contact",
            width: 150
        }, {
            field: "Phone",
            title: "Phone",
            width: 150,
            editor: spark.grid.createFormattedFieldEditor({mask: getDataSource().getFieldSchema("Phone").mask || null})
        }, {
            field: "SalesRep",
            title: "Sales Rep",
            width: 150,
            editor: spark.grid.createSingleLookupEditor({
                dataTextField: "RepName",
                dataValueField: "SalesRep",
                dataSource: salesReps,
                filter: "startswith"
            })
        }, {
            field: "CreditLimit",
            attributes: {class: "numbers"},
            hidden: true,
            template: "#=kendo.toString(CreditLimit, 'n2')#",
            title: "Credit Limit",
            width: 120
        }, {
            field: "Balance",
            attributes: {class: "numbers"},
            hidden: true,
            template: "#=kendo.toString(Balance, 'n2')#",
            title: "Balance",
            width: 120
        }, {
            field: "Terms",
            hidden: true,
            title: "Terms",
            width: 150
        }, {
            field: "Discount",
            attributes: {class: "numbers"},
            hidden: true,
            template: "#=kendo.toString(Discount, 'n0')#",
            title: "Discount",
            width: 120
        }, {
            field: "Comments",
            hidden: true,
            title: "Comments",
            width: 150
        }, {
            field: "Fax",
            hidden: true,
            title: "Fax",
            width: 150
        }, {
            field: "EmailAddress",
            title: "Email",
            width: 150
        }];

        gridColumns.push({
            command: ["edit", "destroy"],
            title: "&nbsp;",
            width: 220
        });

        var grid = $(viewName + " div[name=" + gridName + "]").kendoGrid({
            autoBind: false,
            columns: (viewState && viewState.columns) ? viewState.columns : gridColumns,
            columnMenu: true,
            dataSource: getDataSource(),
            editable: "inline",
            excel: {
                allPages: true,
                fileName: "Kendo UI Grid Export.xlsx",
                filterable: true,
                proxyURL: "http://demos.telerik.com/kendo-ui/service/export"
            },
            filterable: true,
            groupable: true,
            height: "90%",
            pageable: {
                refresh: true,
                pageSizes: [10, 20, 40],
                pageSize: 20,
                buttonCount: 5
            },
            reorderable: true,
            resizable: true,
            scrollable: true,
            selectable: false,
            sortable: true,
            toolbar: ["create", "excel", {template: '<a class="k-button" href="javascript:void(0)" onclick="CustomerUpdGridSPACtrl.resetContext()"><i class="fa fa-unlink"></i>&nbsp;Reset Context</a>'}],
            columnMenuInit: function(ev){
                if (ev && ev.container) {
                    var grid = this;
                    var popup = ev.container.data("kendoPopup");
                    var menu = ev.container.find(".k-menu").data("kendoMenu");
                    menu.append({text: "Toggle Editor Style"});
                    menu.bind("select", function(ev2) {
                        if (ev2) {
                            var item = $(ev2.item);
                            if (item && item.text() === "Toggle Editor Style") {
                                var isPopupEditor = (grid.options.editable === "popup");
                                grid.options.editable = (isPopupEditor ? "inline" : "popup");
                                popup.close();
                                menu.close();
                            }
                        }
                    });
                }
            }
        });

        // Moves grid pager to the footer.
        var pager = grid.find(".k-grid-pager");
        if (pager) {
            pager.appendTo($(viewName + " div[name=" + gridName + "Pager]"));
        }

        primaryVM.set("params.searchValue", spark.getQueryStringValue(searchField1) || "");
        if (searchOnLoad) {
            primaryVM.doSearch(); // Perform an initial search to populate the grid.
        }

        $(viewName + " form[name=searchForm]")
            .on("submit", function(ev){
                primaryVM.doSearch(ev);
                ev.preventDefault();
            });
    }

    function resetContext(){
        viewStateJSDO.invoke("clear", {contextType: "grid", contextViewID: viewName, contextTitle: gridName})
            .then(function(jsdo, result, request){
                var cleared = (request.response || {}).clearedRecords || 0;
                if (cleared > 0) {
                    // Destroy the current grid and re-create without any user context present.
                    $(viewName + " div[name=" + gridName + "]").getKendoGrid().destroy();
                    $(viewName + " div[name=" + gridName + "]").empty();
                    $(viewName + " div[name=" + gridName + "Pager]").empty();
                    viewState = null;
                    showGrid();
                }
            });
    }

    var salesReps = [];
    function init(){
        // Create the JSDO for view-state management.
        viewStateJSDO = spark.createJSDO("context");
        fetchViewState()
            .then(function(myStateID, myViewState){
                viewStateID = myStateID;
                viewState = myViewState;

                // Bind the observable to the view.
                kendo.bind($(viewName), primaryVM);

                // Obtain consistent data for dropdowns first.
                var salesRepJSDO = spark.createJSDO("salesrep");
                salesRepJSDO.fill()
                    .done(function(jsdo, status, request){
                        var response = (request || {}).response || {};
                        salesReps = (response.dsSalesrep || {}).ttSalesrep || [];
                        showGrid(); // Initialize grid.
                    });
            });
    }

    function loadTemplates(){
        // Load additional templates for header/footer.
    }

    function destroy(){
        return saveViewState();
    }

    return {
        init: init,
        loadTemplates: loadTemplates,
        destroy: destroy,
        resetContext: resetContext
    };

})();
