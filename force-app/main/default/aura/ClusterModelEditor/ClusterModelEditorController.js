({
    validate: function(component, event, helper){
        var controls = helper.findComponents(component, 'modelNameInput');
        Array.prototype.push.apply(controls, helper.findComponents(component, 'algorithmComboBox'));
        Array.prototype.push.apply(controls, helper.findComponents(component, 'clusterNumberInput'));
        return helper.validateComponents(controls);
    }
})
