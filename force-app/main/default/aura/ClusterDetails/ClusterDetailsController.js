({
    onInit : function(component, event, helper) {
        let jobDetails = component.get("v.jobDetails");
        let clusterIndex = component.get("v.clusterIndex");
        let centroid = jobDetails.state.centroids[clusterIndex];
        component.set('v.centroid', centroid);
        let crd = component.find('clusterResultDetails');
        crd.rebind();
        window.setTimeout(
            $A.getCallback(function() {
                let div = component.find('clusterBox').getElement();
                div.style.backgroundColor = helper.d3clusterColors[clusterIndex];
            }), 1000
        );
    },
})
