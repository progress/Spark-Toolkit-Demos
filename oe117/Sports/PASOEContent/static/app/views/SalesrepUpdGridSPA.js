var SalesrepUpdGridSPACtrl = (function(){
    "use strict";

    var resourceName = "salesrep";
    var searchField1 = "SalesRep";
    var searchOper1 = "startswith";
    var datasetName = "dsSalesrep";
    var tableName = "ttSalesrep";
    var gridName = "MasterGrid";
    var viewName = "#SalesrepUpdGridSPAView";
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
                promise.resolve({});
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
                }
            });
        }
        return _primaryDS;
    }

    function showGrid(){
        var gridColumns = [{            field: "SalesRep",            title: "SalesRep",            width: 120        }, {            field: "RepName",            title: "RepName",            width: 150        }, {            field: "Region",            title: "Region",            width: 120        }, {            field: "MonthQuota_1",            attributes: {class: "numbers"},            template: function(dataItem){
                if (dataItem.MonthQuota_1) {
                    return kendo.toString(dataItem.MonthQuota_1, "n0");
                }
                return 0;
            },            title: "Jan",            width: 100        }, {
            field: "MonthQuota_2",
            attributes: {class: "numbers"},
            template: function(dataItem){
                if (dataItem.MonthQuota_2) {
                    return kendo.toString(dataItem.MonthQuota_2, "n0");
                }
                return 0;
            },
            title: "Feb",
            width: 100
        }, {
            field: "MonthQuota_3",
            attributes: {class: "numbers"},
            template: function(dataItem){
                if (dataItem.MonthQuota_3) {
                    return kendo.toString(dataItem.MonthQuota_3, "n0");
                }
                return 0;
            },
            title: "Mar",
            width: 100
        }, {
            field: "MonthQuota_4",
            attributes: {class: "numbers"},
            template: function(dataItem){
                if (dataItem.MonthQuota_4) {
                    return kendo.toString(dataItem.MonthQuota_4, "n0");
                }
                return 0;
            },
            title: "Apr",
            width: 100
        }, {
            field: "MonthQuota_5",
            attributes: {class: "numbers"},
            template: function(dataItem){
                if (dataItem.MonthQuota_5) {
                    return kendo.toString(dataItem.MonthQuota_5, "n0");
                }
                return 0;
            },
            title: "May",
            width: 100
        }, {
            field: "MonthQuota_6",
            attributes: {class: "numbers"},
            template: function(dataItem){
                if (dataItem.MonthQuota_6) {
                    return kendo.toString(dataItem.MonthQuota_6, "n0");
                }
                return 0;
            },
            title: "Jun",
            width: 100
        }, {
            field: "MonthQuota_7",
            attributes: {class: "numbers"},
            template: function(dataItem){
                if (dataItem.MonthQuota_7) {
                    return kendo.toString(dataItem.MonthQuota_7, "n0");
                }
                return 0;
            },
            title: "Jul",
            width: 100
        }, {
            field: "MonthQuota_8",
            attributes: {class: "numbers"},
            template: function(dataItem){
                if (dataItem.MonthQuota_8) {
                    return kendo.toString(dataItem.MonthQuota_8, "n0");
                }
                return 0;
            },
            title: "Aug",
            width: 100
        }, {
            field: "MonthQuota_9",
            attributes: {class: "numbers"},
            template: function(dataItem){
                if (dataItem.MonthQuota_9) {
                    return kendo.toString(dataItem.MonthQuota_9, "n0");
                }
                return 0;
            },
            title: "Sep",
            width: 100
        }, {
            field: "MonthQuota_10",
            attributes: {class: "numbers"},
            template: function(dataItem){
                if (dataItem.MonthQuota_10) {
                    return kendo.toString(dataItem.MonthQuota_10, "n0");
                }
                return 0;
            },
            title: "Oct",
            width: 100
        }, {
            field: "MonthQuota_11",
            attributes: {class: "numbers"},
            template: function(dataItem){
                if (dataItem.MonthQuota_11) {
                    return kendo.toString(dataItem.MonthQuota_11, "n0");
                }
                return 0;
            },
            title: "Nov",
            width: 100
        }, {
            field: "MonthQuota_12",
            attributes: {class: "numbers"},
            template: function(dataItem){
                if (dataItem.MonthQuota_12) {
                    return kendo.toString(dataItem.MonthQuota_12, "n0");
                }
                return 0;
            },
            title: "Dec",
            width: 100
        }];

        gridColumns.push({
            command: ["edit", "destroy"],
            title: "&nbsp;",
            width: 200
        });

        var grid = $(viewName + " div[name=" + gridName + "]").kendoGrid({
            autoBind: false,
            columns: (viewState && viewState.columns) ? viewState.columns : gridColumns,
            columnMenu: true,
            dataSource: getDataSource(),
            editable: {
                mode: "inline"
            },
            excel: {
                allPages: true,
                fileName: "Kendo UI Grid Export.xlsx",
                filterable: true,
                proxyURL: "http://demos.telerik.com/kendo-ui/service/export"
            },
            filterable: true,
            groupable: true,
            pageable: {
                alwaysVisible: false,
                pageSize: 20
            },
            reorderable: true,
            resizable: true,
            scrollable: true,
            selectable: false,
            sortable: true,
            toolbar: ["create", "excel"]
        });

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

    function init(){
        // Create the JSDO for view-state management.
        viewStateJSDO = spark.createJSDO("context");
        fetchViewState()
            .then(function(myStateID, myViewState){
                viewStateID = myStateID;
                viewState = myViewState;

                // Bind the observable to the view.
                kendo.bind($(viewName), primaryVM);

                showGrid(); // Initialize grid.
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
        destroy: destroy
    };

})();
