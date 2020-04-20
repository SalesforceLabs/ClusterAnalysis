({
    onInit : function(component, event, helper) {
        helper.init();
        let initJobDetails = component.get("v.initJobDetails");
        if (!initJobDetails) return;
        var action = component.get("c.getJob");
        action.setParams({ jobId : component.get("v.recordId") });

        action.setCallback(this, helper.getServerCallbackFunction(component, helper, 
            function(uiModel) {
                component.set("v.jobDetails", uiModel);
                helper.loadDataPoints(component);
            },
            function (state, errors) {
            })
        );
        $A.enqueueAction(action);
    },

    setJobDetails: function(component, event, helper) {
        var params = event.getParam('arguments');
        if (params && params.jobDetails) {
            component.set('v.jobDetails', params.jobDetails);
            helper.loadDataPoints(component);
        }

    },

    redraw: function(component, event, helper) {
        let distances = component.get('v.distances');
        if (distances) {
            helper.drawTSNE3(component, component.get("v.dataPoints"), component.get('v.jobDetails'), distances);
        }
    }
})
