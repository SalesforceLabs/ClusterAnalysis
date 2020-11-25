({
    onInit : function(component, event, helper) {
        
    },

    fieldSelectChange: function(component, event, helper) {
        var eventSource = event.getSource();
        var fieldValue = eventSource.get('v.value');
        var fields = component.get('v.fields');
        var selectedField = fields.find( f => f.value === fieldValue);
        var index = eventSource.get('v.name').split('_')[1];
        var expressionFields = component.get('v.expressionFields');
        expressionFields[index].field = selectedField;
        var evInputs = component.find('evInput');
        var evInput = ($A.util.isArray(evInputs)) ? evInputs[index] : evInputs;
        evInput.set('v.expressionField',expressionFields[index]);
        helper.fireQueryChangeEvent(component);
    },
    expressionDeleteClick: function(component, event, helper) {
        var eventSource = event.getSource();
        var index = eventSource.get('v.value');
        var expressionFields = component.get('v.expressionFields');
        expressionFields.splice(index, 1);        
        component.set('v.expressionFields',expressionFields);
        helper.fireQueryChangeEvent(component);
    },
    expressionAddClick: function(component, event, helper) {
        var expressionFields = component.get('v.expressionFields');
        var newExpression = { fieldValue: '', operation: '', value: ''};
        expressionFields.push(newExpression);
        component.set('v.expressionFields',expressionFields);
    },
    customLogicChange: function(component, event, helper) {
        helper.fireQueryChangeEvent(component);
    },
    queryChangeEventHandler: function (component, event, helper) {
        console.log('Received query change event');
    },
    validate: function(component, event, helper){
        var fields = helper.findComponents(component, 'fieldComboBox');
        var operations = helper.findComponents(component, 'operationComboBox');
        Array.prototype.push.apply(fields, operations);
        return helper.validateComponents(fields);
    },
    setModelFilter: function(component, event, helper){
        var params = event.getParam('arguments');
        var fields = component.get('v.fields');
        if (params) {
            if (params.filter) {
                params.filter.expressionFields.forEach((expressionField, index) => {
                    expressionField.field = fields.find(field => field.value == expressionField.fieldValue);
                });
                component.set('v.expressionFields', params.filter.expressionFields);
                component.set('v.customLogic', params.filter.customLogic);
                //var evInputs = helper.findComponents(component, 'evInput');
            }
        }

    }
})