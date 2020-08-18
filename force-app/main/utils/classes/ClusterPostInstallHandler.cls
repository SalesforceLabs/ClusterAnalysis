global with sharing class ClusterPostInstallHandler implements InstallHandler {
    global void onInstall(InstallContext context) {
        Logger log = LogFactory.getLogger();
        log.debug('Starting post install script');
        if(context.previousVersion() == null) {
            log.debug('Inserting example models');
            List<String> modelJsonList = new List<String>();
            modelJsonList.add('{"algorithm":"K-Means","numberOfClusters":"4","parameters":{},"isCustomSoql":false,"soql":"SELECT AnnualRevenue, Id, Name, NumberOfEmployees FROM Account",' 
                + '"filter":"{\\"expressionFields\\":[],\\"customLogic\\":\\"\\"}","objectName":"Account","fields":[{"name":"AnnualRevenue","displayLabel":"Annual Revenue","relationName":"",'
                + '"objectName":"Account","distanceType":"Numeric","weight":1},{"name":"Id","displayLabel":"Account ID","relationName":"","objectName":"Account","distanceType":"None","weight":1},'
                + '{"name":"Name","displayLabel":"Account Name","relationName":"","objectName":"Account","distanceType":"None","weight":1},{"name":"NumberOfEmployees","displayLabel":"Employees",'
                + '"relationName":"","objectName":"Account","distanceType":"Numeric","weight":1}],"name":"Account Revenue&NumberOfEmployees Example Model","description":"This model is created as an example"}');

            modelJsonList.add('{"algorithm":"K-Medoids","numberOfClusters":"5","parameters":{},"isCustomSoql":false,"soql":"SELECT Id, Industry, Name, NumberOfEmployees FROM Lead",'
                + '"filter":"{\\"expressionFields\\":[],\\"customLogic\\":\\"\\"}","objectName":"Lead","fields":[{"name":"Id","displayLabel":"Lead ID","relationName":"","objectName":"Lead","distanceType":"None","weight":1},'
                + '{"name":"Industry","displayLabel":"Industry","relationName":"","objectName":"Lead","distanceType":"Category","weight":1},{"name":"Name","displayLabel":"Full Name","relationName":"","objectName":"Lead",'
                + '"distanceType":"None","weight":1},{"name":"NumberOfEmployees","displayLabel":"Employees","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1}],"name":"Lead Industry&NumberOfEmployees Example Model","description":"This model is created as an example"}');

            modelJsonList.add('{"algorithm":"K-Means","numberOfClusters":"4","parameters":{},"isCustomSoql":false,"soql":"SELECT Amount, Id, Name, Probability FROM Opportunity WHERE StageName = \'Prospecting\'",'
                + '"filter":"{\\"expressionFields\\":[{\\"fieldValue\\":\\"Opportunity.StageName\\",\\"value\\":\\"Prospecting\\",\\"operation\\":\\"EQ\\"}],\\"customLogic\\":\\"\\"}","objectName":"Opportunity","fields":'
                + '[{"name":"Amount","displayLabel":"Amount","relationName":"","objectName":"Opportunity","distanceType":"Numeric","weight":1},{"name":"Id","displayLabel":"Opportunity ID","relationName":"",'
                + '"objectName":"Opportunity","distanceType":"None","weight":1},{"name":"Name","displayLabel":"Name","relationName":"","objectName":"Opportunity","distanceType":"None","weight":1},'
                + '{"name":"Probability","displayLabel":"Probability (%)","relationName":"","objectName":"Opportunity","distanceType":"Numeric","weight":1}],"name":"Opportunity Amount&Probability Example Model","description":"This model is created as an example"}');

            for (String modelJson:modelJsonList) {
                ClusterModelWrapper model = ClusterModelBuilderController.saveModel(modelJson);
                log.debug('Created model with id ' + model.modelId);
            }
        }
        else {

        }
        log.debug('Post install script completed');
    }
}