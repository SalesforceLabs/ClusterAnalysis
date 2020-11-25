({
    validateComponents: function(components){
        var valid = true;
        components.forEach(component => {
            if (component){
                valid &= !component.get('v.validity').valueMissing;
                component.showHelpMessageIfInvalid();
            }
        });
        return valid;
    },
    findComponents: function(component, auraid){
        var components = component.find(auraid);
        if($A.util.isEmpty(components)) { 
            components = [];
        }
        if(!$A.util.isArray(components)) {
            components = [ components ];
        }
        return components;
    },
})