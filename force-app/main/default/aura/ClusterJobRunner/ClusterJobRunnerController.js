({
    onInit : function(component, event, helper) {
        let action = component.get("c.getModels");

        action.setCallback(this, helper.getServerCallbackFunction(component, helper, 
            function(uiModel) {
                component.set("v.jobRunnerModel", uiModel);
                let sectionsMap = [];
                for (let i=0; i < uiModel.models.length; i++) {
                    let section = sectionsMap.find(item => item.label == uiModel.models[i].objectName);
                    if (!section) {
                        section = { label: uiModel.models[i].objectName, models: [] };
                        sectionsMap.push(section);
                    }
                    section.models.push(uiModel.models[i]);
                }
                component.set('v.sectionsMap', sectionsMap);
            },
            function (state, errors) {
            })
        );
        $A.enqueueAction(action);
    },
    onModelSelect : function(component, event, helper) {
        let selected = event.getParam('name');
        let uiModel = component.get("v.jobRunnerModel");
        if (selected) {
            let model = uiModel.models.find(m => m.modelId == selected);
            if (model) {
                let parameters = uiModel.parameters[model.algorithm];
                if (parameters) {
                    parameters.forEach(param => {
                        if (param.name == 'numberOfClusters') {
                            param.value = model.numberOfClusters;
                        }
                    });
                    component.set('v.parameters', parameters);
                }
            }
        }
    },
    cancelButtonClick : function(component, event, helper) {
        window.history.back();
    },
    runButtonClick : function(component, event, helper) {
        let action = component.get("c.runModel");
        let modelId = component.get("v.selectedModel");
        let parameters = component.get("v.parameters");
        let params = parameters.reduce(function(map, param) {
            map[param.name] = param.value;
            return map;
        }, {});
        action.setParams({ modelId : modelId, parameters : params });

        action.setCallback(this, helper.getServerCallbackFunction(component, helper, 
            function(clusterJobId) {
                if (clusterJobId) {
                    var navLink = component.find("navigation");
                    var pageRef = {
                        type: 'standard__recordPage',
                        attributes: {
                            actionName: 'view',
                            recordId : clusterJobId
                        },
                    };
                    navLink.navigate(pageRef, true);
                    var vfCallBack = component.get('v.vfCallBack');
                    if (vfCallBack) {
                        vfCallBack(clusterJobId);
                    }
                }
                else {
                    helper.showNotification(component, "error", "Something has gone wrong!", "Clustering job has failed to start");
                }
            },
            function (state, errors) {
            })
        );
        $A.enqueueAction(action);
    },
})