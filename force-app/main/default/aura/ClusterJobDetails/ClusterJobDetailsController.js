({
    onInit : function(component, event, helper) {
        component.set('v.isVisible', true);
        component.set('v.pollingCount', 0);
        helper.loadJobDetails(component, event, helper, false);
    },
    cancelButtonClick : function(component, event, helper) {
        helper.cancelJob(component, event, helper);
    },
    editJobNameClick: function(component, event, helper) {
        helper.editJobName(component, event, helper);
    },
    saveJobNameClick: function(component, event, helper) {
        helper.saveJobName(component, event, helper);
    },
    cancelJobNameClick: function(component, event, helper) {
        helper.cancelJobNameEdit(component, event, helper);
    },
    tsneParameterChange : function(component, event, helper) {
        let collide = component.find('collideInput').get('v.checked');
        let perplexity = component.get('v.perplexity');
        let epsilon = component.get('v.epsilon');
        let tsne = component.find('tsneGraph');
        let oldCollide = tsne.get('v.collide');
        let oldPerplexity = tsne.get('v.perplexity');
        let oldEpsilon = tsne.get('v.epsilon');
        if (oldCollide != collide || oldEpsilon != epsilon || oldPerplexity != perplexity) {
            tsne.set('v.collide', collide);
            tsne.set('v.epsilon', epsilon);
            tsne.set('v.perplexity', perplexity);
            let timeoutId = component.get('v.timeoutId');
            if (timeoutId) {
                window.clearTimeout(timeoutId);
                component.set('v.timeoutId', null);
            }
            timeoutId = window.setTimeout(
                $A.getCallback(function() {
                    tsne.redraw();
                    component.set('v.timeoutId', null);
                }), 1000
            );
            component.set('v.timeoutId', timeoutId);
        }
    },
    graphDataPointHoverEventHandler: function(component, event) {
        component.set('v.tsneTooltipVisible', true);
        let tsneDetails = component.find('tsneDetails');
        let dataPoint = event.getParam("dataPoint");
        tsneDetails.set('v.dataPoint', dataPoint);
        tsneDetails.rebind();
    },
    handleDestroy : function (component, event, helper) {
        component.set('v.isVisible', false);
    }
})