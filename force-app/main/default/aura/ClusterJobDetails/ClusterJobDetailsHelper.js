({
    loadJobDetails : function(component, event, helper, isPolling){
        let action = component.get("c.getJob");
        action.setParams({ jobId : component.get("v.recordId") });

        action.setCallback(this, helper.getServerCallbackFunction(component, helper, 
            function(uiModel) {
                if (uiModel.jobStateString && uiModel.jobStateString !== '') {
                    uiModel.state = JSON.parse(uiModel.jobStateString);
                }
                component.set("v.jobDetails", uiModel);
                let jobDetails = component.get("v.jobDetails");
                if (!((jobDetails.status == "InProgress") || (jobDetails.status == "New"))) {                    
                    if (uiModel.status == "Completed") {
                        let tsneGraph = component.find('tsneGraph');
                        component.set('v.silhouetteStrength', Math.round(uiModel.score * 3).toString());
                        tsneGraph.setJobDetails(uiModel);
                    }
                    if (isPolling) {
                        $A.get('e.force:refreshView').fire();
                    }
                }
                else {
                    helper.setPolling(component, event, helper);
                }
            },
            function (state, errors) {
            })
        );
        $A.enqueueAction(action);
    },
    setPolling : function(component, event, helper) {
        let jobDetails = component.get("v.jobDetails");
        let isVisible = component.get('v.isVisible');
        if (isVisible && ((jobDetails.status == "InProgress") || (jobDetails.status == "New"))) {
            window.setTimeout(
                $A.getCallback(function() {
                    helper.loadJobDetails(component, event, helper, true);
                }), 15000
            );
        }
    },
    cancelJob : function(component, event, helper){
        let action = component.get("c.cancelJob");
        action.setParams({ jobId : component.get("v.recordId") });

        action.setCallback(this, helper.getServerCallbackFunction(component, helper, 
            function(uiModel) {
                component.set("v.jobDetails", uiModel);
                $A.get('e.force:refreshView').fire();
            },
            function (state, errors) {
            })
        );
        $A.enqueueAction(action);
    },
    editJobName: function(component, event, helper) {
        let jobDetails = component.get("v.jobDetails");
        jobDetails.jobNameBackup = jobDetails.jobName;
        component.set('v.isEditMode', true);
    },
    saveJobName: function(component, event, helper) {
        let action = component.get("c.setJobName");
        let jobDetails = component.get("v.jobDetails");
        let jobNameInput = component.find('jobNameInput');
        jobDetails.jobName = jobNameInput.getElement().value; //For some reason 2 way binding doesn't work here
        action.setParams({ jobId : component.get("v.recordId"), jobName : jobDetails.jobName });

        action.setCallback(this, helper.getServerCallbackFunction(component, helper, 
            function(uiModel) {
                component.set('v.isEditMode', false);
                if (uiModel.jobStateString && uiModel.jobStateString !== '') {
                    uiModel.state = JSON.parse(uiModel.jobStateString);
                }
                component.set("v.jobDetails", uiModel);                
            },
            function (state, errors) {
            })
        );
        $A.enqueueAction(action);
    },
    cancelJobNameEdit: function(component, event, helper) {
        let jobDetails = component.get("v.jobDetails");
        jobDetails.jobName = jobDetails.jobNameBackup;
        component.set('v.jobDetails', jobDetails);
        component.set('v.isEditMode', false);
    },

})
