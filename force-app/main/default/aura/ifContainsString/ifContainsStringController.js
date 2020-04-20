({
    doInit : function(component, event, helper) {
        var string = component.get('v.string').toLowerCase();
        var subString = component.get('v.subString').toLowerCase();
        component.set('v.condition', (!subString) || (string.indexOf(subString) > -1));
    }
})
