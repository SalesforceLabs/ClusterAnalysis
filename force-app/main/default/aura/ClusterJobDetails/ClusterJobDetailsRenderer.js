({

    unrender: function (component,helper) {
        this.superUnrender();
        if (component) {
            component.set('v.isVisible', false);
        }
    }

})