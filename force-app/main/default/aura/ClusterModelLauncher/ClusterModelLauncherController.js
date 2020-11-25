({
    onInit : function(component, event, helper) {
        var action = component.get("c.loadModel");
        action.setParams({ modelId : component.get("v.recordId") });

        action.setCallback(this, helper.getServerCallbackFunction(component, helper, 
            function(uiModel) {
                component.set("v.uiModel", uiModel);
            },
            function (state, errors) {
            })
        );
        $A.enqueueAction(action);
    },
    runClick : function (component, event, helper) {
        var action = component.get("c.runModel");
        var uiModel = component.get("v.uiModel");
        var params = uiModel.parameters.reduce(function(map, param) {
            map[param.name] = param.value;
            return map;
        }, {});
        action.setParams({ modelId : component.get("v.recordId"), parameters : params });

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
    cancelClick : function (cmp, event, helper) {
        $A.get("e.force:closeQuickAction").fire();
    }
})