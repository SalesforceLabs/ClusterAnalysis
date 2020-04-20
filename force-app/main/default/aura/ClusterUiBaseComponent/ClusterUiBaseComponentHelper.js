({
    getServerCallbackFunction: function(component, helper, successCallback, failureCallback) {
        return function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                if (successCallback) successCallback(response.getReturnValue());
            }
            else if (state === "INCOMPLETE") {
                helper.showNotification(component, "error", "Something has gone wrong!", "Unfortunately the server call was not completed");
                if (failureCallback) failureCallback(state);
            }
            else if (state === "ERROR") {
                var errors = response.getError();
                var displayError = '';
                if (errors) {
                    errors.forEach(error => {
                        if (error.message) {
                            displayError += error.message + '\r\n';
                        }
                        //page-level errors (validation rules, etc)
                        if (error.pageErrors){
                            error.pageErrors.forEach( function(pageError) {
                                displayError += pageError.message + '\r\n';
                            });					
                        }

                        if (error.fieldErrors){
                            //field specific errors
                            for (var fieldName in error.fieldErrors) {
                                error.fieldErrors[fieldName].forEach( function (errorList){	
                                    displayError += fieldName + ': ' + errorList.message + '\r\n';
                                });                                
                            };
                        }
                    });
                } else {
                    displayError = "Unknown error";                    
                }
                console.log("Error message: " + displayError);
                helper.showNotification(component, "error", "Something has gone wrong!", "Unfortunately the server call returned en error: " + displayError);
                if (failureCallback) failureCallback(state, errors);
            }
        };
    },
    showNotification: function(component, variant, header, message, callback){
        component.find('notifLib').showNotice({
            "variant": variant,
            "header": header,
            "message": message,
            closeCallback: callback
        });
    },
})
