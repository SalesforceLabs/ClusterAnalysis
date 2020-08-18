({
    onInit : function(component, event, helper) {
        helper.loadJobResultDetails(component, event, helper);
    },
    jobLinkClick: function(component, event, helper) {
        let jobResultDetails = component.get("v.jobResultDetails");
        if (jobResultDetails) {
            helper.navigateToId(component, event, jobResultDetails.jobId);
        }
    },
    clusterLinkClick: function(component, event, helper) {
        let jobResultDetails = component.get("v.jobResultDetails");
        if (jobResultDetails) {
            helper.navigateToId(component, event, jobResultDetails.clusterId);
        }        
    }

})