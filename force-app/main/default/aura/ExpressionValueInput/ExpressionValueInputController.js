({
    expressionValueChange : function(component, event, helper) {
        var queryChangeEvent = component.getEvent("queryChangeEvent");
        queryChangeEvent.fire();
    }
})
