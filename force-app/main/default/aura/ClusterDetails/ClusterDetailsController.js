({
    onInit : function(component, event, helper) {
        let jobDetails = component.get("v.jobDetails");
        let clusterIndex = component.get("v.clusterIndex");
        let centroidValues = jobDetails.state.centroids[clusterIndex].values;
        let centroid = centroidValues.map((cv,index) => {return { name: jobDetails.model.fields[index].name, value: cv } });
        component.set('v.centroid', centroid);
        window.setTimeout(
            $A.getCallback(function() {
                let div = component.find('clusterBox').getElement();
                div.style.backgroundColor = helper.d3clusterColors[clusterIndex];
            }), 1000
        );
    },
})
