({
    onInit : function(component, event, helper) {
        helper.setWizardPage(component, 0);
        component.set('v.clusterObjectLoading', true);
        var action = component.get("c.getModel");
        action.setParams({ modelId : component.get("v.recordId") });

        action.setCallback(this, helper.getServerCallbackFunction(component, helper, 
            function(uiModel) {
                uiModel.objectName = uiModel.model.objectName;
                component.set("v.clusterModel", uiModel);
                component.set('v.queryObjects', uiModel.queryObjects);
                component.set('v.soqlQuery', uiModel.model.soql);
                if (uiModel.queryObjects && uiModel.queryObjects.length) {
                    setTimeout($A.getCallback(
                        () => {
                            component.set("v.activeSection", 'section_' + uiModel.queryObjects[0].name);
                            var exprBuilder = component.find('expBuilder');
                            exprBuilder.set('v.fields',uiModel.queryObjects[0].fields);
                            var exprFilter = (uiModel.model.filter) ? JSON.parse(uiModel.model.filter) : null;
                            if (exprFilter) {
                                exprBuilder.setModelFilter(exprFilter);
                                //exprBuilder.set('v.expressionFields', exprFilter.expressionFields);
                                //exprBuilder.set('v.customLogic', exprFilter.customLogic);
                            }                            
                            component.set('v.clusterObjectLoading', false);
                        }
                    ));
                }
                else{ 
                    component.set('v.clusterObjectLoading', false);
                }
            },
            function (state, errors) {
                component.set('v.clusterObjectLoading', false);
            })
        );
        $A.enqueueAction(action);
    },

    clusterObjectSelectChange : function (component, event, helper) {
        var action = component.get("c.getQueryObjects");
        var model = component.get("v.clusterModel");
        var selectedObject = model.objectName;
        component.set('v.clusterObjectLoading', true);
        //TODO: set wrapper properties
        action.setParams({ objectName : selectedObject });
        action.setCallback(this, helper.getServerCallbackFunction(component, helper,
            function(returnValue) {
                model.queryObjects = returnValue;
                component.set('v.queryObjects', returnValue);
                if (model.queryObjects && model.queryObjects.length) {
                    setTimeout($A.getCallback(
                        () => {
                            component.set("v.activeSection", 'section_' + model.queryObjects[0].name);
                            var exprBuilder = component.find('expBuilder');
                            exprBuilder.set('v.fields',model.queryObjects[0].fields);
                            exprBuilder.set('v.expressionFields', []);
                            helper.generateSoqlQuery(component);
                            component.set('v.clusterObjectLoading', false);
                        }
                    ));
                }
            },
            function (state, errors) {
                component.set('v.clusterObjectLoading', false);
            }
        ));
        $A.enqueueAction(action);
    },

    queryFieldChange : function (component, event, helper) {
        helper.generateSoqlQuery(component);
    },

    soqlInputChange : function (component, event, helper) {
        var model = component.get("v.clusterModel");
        model.model.isCustomSoql = true;
    },

    queryChangeEventHandler: function (component, event, helper) {
        helper.generateSoqlQuery(component);
    },

    selectAllChange: function (component, event, helper) {
        var sourceCheckbox = event.getSource();
        var index = sourceCheckbox.get('v.value');
        var checked = sourceCheckbox.get('v.checked');
        var model = component.get("v.clusterModel");
        var checkboxDivs = helper.findComponents(component, 'queryFieldSet')[index].get('v.body')[0].get('v.body');
        for (var i=0, len=checkboxDivs.length; i<len; i++){
            checkboxDivs[i].get('v.body')[0].set('v.checked', checked);
        }
        model.queryObjects[index].fields.forEach((item, ind, arr) => item.checked = checked);
        helper.generateSoqlQuery(component);
    },

    searchChange: function (component, event, helper) {
        let timeoutId = component.get('v.timeoutId');
        if (timeoutId) {
            window.clearTimeout(timeoutId);
            component.set('v.timeoutId', null);
        }
        timeoutId = window.setTimeout(
            $A.getCallback(function() {
                helper.fieldSearch(component);
                component.set('v.timeoutId', null);
            }), 500
        );
        component.set('v.timeoutId', timeoutId);        
    },

    progressStepFocus: function(component, event, helper) {
        event.stopPropagation();
    },

    nextButtonClick: function(component, event, helper) {
        helper.wrapTryCatch(component, () => {
            var wizardPage = component.get('v.wizardPage');
            var model = component.get("v.clusterModel");
            if (wizardPage == 0) {
                //TODO: implement verification and field population from SOQL query
                var validationError = helper.verifySoqlAndPopulateFields(component, model);
                if (!validationError) {
                    var cmEditor = component.find('cmEditor');
                    cmEditor.set('v.clusterModel', model);
                    component.set('v.wizardPage', ++wizardPage);
                    helper.setWizardPage(component, wizardPage);
                }
                else {
                    helper.showNotification(component, "error", "Model validation error", validationError);
                    helper.setWizardPage(component, 0);
                }
            }
        });
    },

    saveButtonClick: function(component, event, helper) {
        helper.wrapTryCatch(component, () => {
            var wizardPage = component.get('v.wizardPage');
            var model = component.get("v.clusterModel");
            if (wizardPage == 1) {
                if (helper.validateModelEditor(component, model)) {
                    var model = component.get("v.clusterModel");
                    var action = component.get("c.saveModel");
                    action.setParams({ "modelJson" : JSON.stringify(model.model) });
                    action.setCallback(this, helper.getServerCallbackFunction(component, helper, function(returnValue) {
                            model.modelId = returnValue.modelId;
                            component.find("navigation").navigate({
                                "type" : "standard__recordPage",
                                "attributes": {
                                    "recordId": model.modelId,
                                    "actionName": "view"
                                }
                            }, true);
                            var vfCallBack = component.get('v.vfCallBack');
                            if (vfCallBack) {
                                vfCallBack();
                            }
                        })
                    );
                    $A.enqueueAction(action);
                }
            }
        });
    },


    backButtonClick: function(component, event, helper) {
        var wizardPage = component.get('v.wizardPage');
        if (wizardPage > 0) {
            component.set('v.wizardPage', --wizardPage);
            helper.setWizardPage(component, wizardPage);
        }
    },

    cancelButtonClick: function(component, event, helper) {
        window.history.back();
    },

})
