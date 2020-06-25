({
    onInit : function(component, event, helper) {
        helper.rebind(component, event, helper);
    },

    rebind: function(component, event, helper) {
        helper.rebind(component, event, helper);
    },

    recordLinkClick: function(component, event, helper) {
        let dataPoint = component.get("v.dataPoint");
        var navEvt = $A.get("e.force:navigateToSObject");
        navEvt.setParams({
            "recordId": dataPoint.externalId,
            "slideDevName": "Detail"
        });
        navEvt.fire();
        event.preventDefault();
    }
    
})
