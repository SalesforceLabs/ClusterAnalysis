({
    loadJobResultDetails : function(component, event, helper){
        let action = component.get("c.getJobResultModel");
        action.setParams({ jobResultId : component.get("v.recordId") });

        action.setCallback(this, helper.getServerCallbackFunction(component, helper, 
            function(uiModel) {
                if (uiModel.jobStateString && uiModel.jobStateString !== '') {
                    uiModel.jobState = JSON.parse(uiModel.jobStateString);
                }
                component.set("v.jobResultDetails", uiModel);
                let dpDetails = component.find('dataPointDetails');
                dpDetails.set('v.dataPoint', uiModel.dataPoint);
                dpDetails.set('v.jobState', uiModel.jobState);
                dpDetails.set('v.clusterColor', uiModel.clusterColor);
                dpDetails.rebind();
            },
            function (state, errors) {
            })
        );
        $A.enqueueAction(action);
    },
    navigateToId: function(component, event, recordId) {
        var navEvt = $A.get("e.force:navigateToSObject");
        navEvt.setParams({
            "recordId": recordId,
            "slideDevName": "Detail"
        });
        navEvt.fire();
        event.preventDefault();
    }
})