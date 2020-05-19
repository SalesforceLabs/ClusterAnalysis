({
    operationsMap : [{'soqlOperation': '=', 'operation': 'EQ'},
        {'soqlOperation': '<>', 'operation': 'NE'},
        {'soqlOperation': '>', 'operation': 'GT'},
        {'soqlOperation': '<', 'operation': 'LT'},
        {'soqlOperation': 'LIKE', 'operation': 'SW'},
        {'soqlOperation': 'LIKE', 'operation': 'EW'},
        {'soqlOperation': 'LIKE', 'operation': 'LK'},
        {'soqlOperation': 'IN', 'operation': 'IN'},
        {'soqlOperation': 'NOT IN', 'operation': 'NI'}],

    initView : function() {

    },

    getServerCallbackFunction: function(component, helper, successCallback, failureCallback) {
        return function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                if (successCallback) successCallback(response.getReturnValue());
            }
            else if (state === "INCOMPLETE") {
                helper.showNotification(component, "error", "Something has gone wrong!", "Unfortunately the server call was not completed");
                if (failureCallback) failureCallback(state);
            }
            else if (state === "ERROR") {
                var errors = response.getError();
                var displayError = '';
                if (errors) {
                    errors.forEach(error => {
                        if (error.message) {
                            displayError += error.message + '\r\n';
                        }
                        //page-level errors (validation rules, etc)
                        if (error.pageErrors){
                            error.pageErrors.forEach( function(pageError) {
                                displayError += pageError.message + '\r\n';
                            });					
                        }

                        if (error.fieldErrors){
                            //field specific errors
                            for (var fieldName in error.fieldErrors) {
                                error.fieldErrors[fieldName].forEach( function (errorList){	
                                    displayError += fieldName + ': ' + errorList.message + '\r\n';
                                });                                
                            };
                        }
                    });
                } else {
                    displayError = "Unknown error";                    
                }
                console.log("Error message: " + displayError);
                helper.showNotification(component, "error", "Something has gone wrong!", "Unfortunately the server call returned an error: " + displayError);
                if (failureCallback) failureCallback(state, errors);
            }
        };
    },

    wrapTryCatch: function(component, action, catchAction) {
        try {
            action();
        }
        catch (e){
            console.error(e);
            if (catchAction) catchAction();
            this.showNotification(component, "error", "Something has gone wrong!", "Unfortunately the following error has occurred: " + e.message);
        }
    },

    showNotification: function(component, variant, header, message, callback){
        component.find('notifLib').showNotice({
            "variant": variant,
            "header": header,
            "message": message,
            closeCallback: callback
        });
    },

    setWizardPage: function(component, pageIndex){
        var page0 = component.find('wizPage0');
        var page1 = component.find('wizPage1');
        if (pageIndex == 0){
            $A.util.addClass(page1, 'slds-hide');
            $A.util.removeClass(page0, 'slds-hide');            
        }
        else if (pageIndex == 1) {
            $A.util.addClass(page0, 'slds-hide');
            $A.util.removeClass(page1, 'slds-hide');
        }
        component.set('v.progressStep', 'Step'+pageIndex);
    },

    validateModelEditor: function(component, model){
        var cmEditor = component.find('cmEditor');
        var valid = cmEditor.validate();
        if (!valid){
            this.showNotification(component, "error", "Model validation error", "Model configuration has errors");
        }
        return valid;
    },

    fieldSearch: function(component) {
        var searchField = component.get("v.searchField").toLowerCase();
        var fieldDivs = component.find('queryfielddiv');
        if($A.util.isEmpty(fieldDivs)) { 
            fieldDivs = [];
        }
        if(!$A.util.isArray(fieldDivs)) {
            fieldDivs = [ fieldDivs ];
        }

        fieldDivs.forEach((item,index,arr) => {
            var elem = item.getElement();
            if (elem) {
                var str = elem.dataset.string.toLowerCase();
                if ((!searchField) || (str.indexOf(searchField) > -1)) {
                    $A.util.removeClass(item, 'slds-hide');
                }
                else {
                    $A.util.addClass(item, 'slds-hide');
                }
            }
        });
    },
    
    verifySoqlAndPopulateFields: function(component, model){
        model.model.objectName = model.objectName;
        var soqlInput = component.find('soqlInput');
        var valid = this.validateComponents([component.find('clusterObjectSelect'), soqlInput]);
        if (valid){
            var exprBuilder = component.find('expBuilder');
            if (!exprBuilder.validate()) return "Filter expression has errors";            
        }
        else {
            return "It is required to select an object and fields to build the model";
        }
        var oldFields = model.model.fields;
        if (model.model.isCustomSoql){
            model.model.soql = component.get('v.soqlQuery');
            var parsedQuery;
            try {
                parsedQuery = clustanSoqlParser.parseSoqlQuery(model.model.soql);
            }
            catch (e) {
                return "Soql parser error: " + e.message;
            }
            if (parsedQuery.groupBy)
                return "SOQL GROUP BY expression is not supported";
            if (parsedQuery.fields) {
                model.model.fields = [];
                for (var i=0; i<parsedQuery.fields.length; i++){
                    var field = parsedQuery.fields[i];
                    switch (field.type){
                        case 'Field':{
                            var queryField = this.findFieldDescByObjectAndFieldName(model, field.field, model.objectName);
                            if (queryField) {
                                model.model.fields.push(this.createFieldWrapperFromQueryField(model, queryField));
                            }
                            else return "Soql parser error: " + field.field + " was not found in meta dictionary";
                            break;
                        }
                        case 'FieldRelationship': {
                            if (!field.relationships || field.relationships.length != 1)
                                return "Soql parser error: Only one level parent relations are supported";
                            var queryField = this.findFieldDescByRelation(model,field.rawValue);
                            if (queryField){
                                model.model.fields.push(this.createFieldWrapperFromQueryField(model, queryField));
                            }
                            else return "Soql parser error: " + field.rawValue + " was not found in meta dictionary";
                            break;
                        }
                        default:
                            return "Soql parser error: " + field.type + " is not supported";
                    }
                }
            }
            else {
                return "Soql parser did not find query fields";
            }
        }
        else {
            var selectedQueryFields = this.getSelectedQueryFields(model);
            model.model.fields = selectedQueryFields.map(qf => this.createFieldWrapperFromQueryField(model, qf));
        }
        var idField = model.model.fields.find(mf => mf.objectName == model.objectName && mf.name.toLowerCase() == 'id');            
        if (!idField) {
            valid = false;
            return "Cluster calculation requires Id and Name fields in the query";
        }
        if (oldFields) {
            //Merge existing and new fields
            model.model.fields.forEach(field => {
                var existingField = oldFields.find(oldField => oldField.name === field.name && oldField.objectName === field.objectName && 
                    (oldField.relationName == field.relationName || (!oldField.relationName && !field.relationName)));
                if (existingField){
                    field.weight = existingField.weight;
                    field.distanceType = existingField.distanceType;
                }
            });
        }
        return null;
    },

    createFieldWrapperFromQueryField: function(model, queryField){
        var fieldWrapper = {
            name: queryField.name,
            displayLabel: queryField.displayLabel,
            relationName: queryField.relationshipName,
            objectName: queryField.objectName,
            distanceType: this.getDistanceTypeFromQueryField(model, queryField),
            weight: 1
        };
        return fieldWrapper;
    },

    getDistanceTypeFromQueryField: function(model, queryField){
        if (queryField.name.toLowerCase() == 'name') return 'None';
        var fieldDesc = this.findFieldDescByObjectAndFieldName(model, queryField.name, queryField.objectName);
        switch (fieldDesc.dataType){
            case 'STRING':
            case 'ENCRYPTEDSTRING':
                return 'Text';
            case 'TEXTAREA':
                return 'LongText';
            case 'DATE':
            case 'DATETIME':
            case 'CURRENCY':
            case 'DOUBLE':
            case 'INTEGER':
            case 'LONG':
            case 'PERCENT':
                return 'Numeric';
            case 'ID':
            case 'REFERENCE':
                return 'None';
            default:
                return 'Category';
        }
    },

    validateComponents: function(components){
        var valid = true;
        components.forEach(component => {
            if (component){
                valid &= !component.get('v.validity').valueMissing;
                component.showHelpMessageIfInvalid();
            }
        });
        return valid;
    },

    addRemoveQueryField: function(model, queryFieldValue, checked){
        var qfSplit = queryFieldValue.split(".");
        var objectName = qfSplit[0];
        var queryObject = model.queryObjects.find( queryObject => queryObject.name === objectName);
        if (queryObject){
            var queryField = queryObject.fields.find( qf => qf.value === queryFieldValue);
            if (queryField) {
                queryField.checked = checked;
            }
        }
    },

    getSelectedQueryFields: function(model){
        var selectedFields = [];
        model.queryObjects.forEach(queryObject => {
            Array.prototype.push.apply(selectedFields, queryObject.fields.filter(queryField => queryField.checked));
        });
        return selectedFields;
    },

    findFieldDescByObjectAndFieldName: function(model, fieldName, objectName){
        var queryObject = model.queryObjects.find( queryObject => queryObject.name === objectName);
        return (queryObject)?queryObject.fields.find( qf => qf.name.toLowerCase() === fieldName.toLowerCase()):null;
    },

    findFieldDescByRelation: function(model, fieldName){
        var qfSplit = fieldName.split(".");
        var objectName = qfSplit[0];
        var queryObject = model.queryObjects.find( queryObject =>(queryObject.relationshipName != null) && (queryObject.relationshipName.toLowerCase() === objectName.toLowerCase()));
        return (queryObject)?queryObject.fields.find( qf => qf.value.toLowerCase() === fieldName.toLowerCase()):null;
    },

    findFieldDesc: function(model, fieldName){
        var qfSplit = fieldName.split(".");
        var objectName = qfSplit[0];
        var queryObject = model.queryObjects.find( queryObject => queryObject.name === objectName || queryObject.relationshipName === objectName);
        return (queryObject)?queryObject.fields.find( qf => qf.value === fieldName):null;
    },

    findComponents: function(component, auraid){
        var components = component.find(auraid);
        if($A.util.isEmpty(components)) { 
            components = [];
        }
        if(!$A.util.isArray(components)) {
            components = [ components ];
        }
        return components;
    },

    generateSoqlQuery: function(component){
        try {
            var model = component.get("v.clusterModel");
            if (model.objectName){
                var exprBuilder = component.find('expBuilder');
                var selectClause = this.buildSelectClause(model);
                var expressionFields = exprBuilder.get('v.expressionFields');
                var customLogic = exprBuilder.get('v.customLogic');
                var whereClause = this.buildWhereClause(model, expressionFields, customLogic);
                var soql = (selectClause) ? ('SELECT ' + this.buildSelectClause(model) + 
                    ' FROM ' + model.objectName +
                    (whereClause === '' ? '' : ' WHERE ' + whereClause)) : '';
                component.set('v.soqlQuery', soql);
                model.model.isCustomSoql = false;
                model.model.soql = soql;
                var modelExpressionFields = (expressionFields) ? expressionFields.map(ef => { return { 'fieldValue': ef.fieldValue, 'value': ef.value, 'operation': ef.operation };}) : [];
                model.model.filter = JSON.stringify({ expressionFields: modelExpressionFields, customLogic: customLogic});
                model.model.objectName = model.objectName;
            }
        }
        catch (e){
            component.set('v.soqlQuery', '');
            this.showNotification(component, "error", "SOQL query error", e.message);
        }
    },

    buildSelectClause: function(model){
        var selectClause = '';
        for (var objIndex=0; objIndex < model.queryObjects.length; objIndex++){
            model.queryObjects[objIndex].fields.forEach(queryField => {
                if (queryField.checked){
                    if (selectClause!=='') selectClause += ', ';
                    if (model.queryObjects[objIndex].name === model.objectName) {
                        selectClause += queryField.name;
                    }
                    else selectClause += queryField.value;
                }
            });
        }
        return selectClause;
    },

    buildWhereClause: function(model, filterFields, customWhereLogic) {
        var whereClause = '';
        if (!filterFields || filterFields.length == 0) return whereClause;
        if (!customWhereLogic) {
            filterFields.forEach(field => {
                if (field.fieldValue && field.operation) {
                    if (whereClause!=='') whereClause += ' AND ';
                    whereClause += this.buildFilterExpression(model, field);
                }
            });
        }
        else {
            const regex = /(\d+)/gm;
            whereClause = customWhereLogic.replace(regex, (match, offset, string) => {
                const exprIndex = parseInt(match);
                if (exprIndex <= filterFields.length)
                    return this.buildFilterExpression(model, filterFields[exprIndex - 1]);
                else {
                    throw "Invalid custom logic index";
                }
            });
        }
        return whereClause;
    },

    buildFilterExpression: function(model, filterExpression){
        var soqlExpression = '';
        if (filterExpression.fieldValue && filterExpression.operation) {
            var fvSplit = filterExpression.fieldValue.split('.');
            soqlExpression = model.objectName == fvSplit[0] ? fvSplit[1] : filterExpression.fieldValue;
            soqlExpression += ' ' + this.translateOperation(filterExpression.operation) + ' ' + this.translateValue(model, filterExpression.value, filterExpression.fieldValue, filterExpression.operation);
        }
        return soqlExpression;
    },

    translateOperation: function(operation){
        var op = this.operationsMap.find(op => op.operation == operation);
        return op ? op.soqlOperation : operation;
    },

    translateValue: function(model, value, fieldName, operation){
        if (value === '' || value === null) return "null";
        var fieldDesc = this.findFieldDesc(model, fieldName);
        var quoteValue = this.quotesNeeded(fieldDesc);
        switch (operation){
            case 'IN':
            case 'NI':
                return '(' + value + ')';                
            case 'SW':
                value +='%';
                quoteValue = true;
                break;
            case 'EW':
                value = '%' + value;
                quoteValue = true;
                break;
            case 'LK':
                value = '%' + value + '%';
                quoteValue = true;
                break;
        }
        var result = this.escapeString(value);
        return quoteValue ? "'" + result + "'" : result;
    },

    quotesNeeded: function(fieldDesc){
        switch (fieldDesc.dataType){
            case 'BOOLEAN':
            case 'DATE':
            case 'DATETIME':
            case 'CURRENCY':
            case 'DOUBLE':
            case 'INTEGER':
            case 'LONG':
            case 'PERCENT':
                return false;
            default:
                return true;
        }
    },

    escapeString: function(str) {
        var pattern = new RegExp("[\\0\\x08\\x09\\x1a\\n\\r\"\'\\\\\\%]","g"); // /[\0\x08\x09\x1a\n\r"'\\\%]/g
        return str.replace(pattern, function (char) {
            switch (char) {
                case "\0":
                    return "\\0";
                case "\x08":
                    return "\\b";
                case "\x09":
                    return "\\t";
                case "\x1a":
                    return "\\z";
                case "\n":
                    return "\\n";
                case "\r":
                    return "\\r";
                case "\"":
                case "'":
                case "\\":
                case "%":
                    return "\\"+char; // prepends a backslash to backslash, percent,
                                      // and double/single quotes
            }
        });
    }

})
