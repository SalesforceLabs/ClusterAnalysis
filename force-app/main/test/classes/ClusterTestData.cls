@isTest
public with sharing class ClusterTestData {
    public static User createClusterAdmin() {
        // Create a unique UserName
        String uniqueUserName = 'clusteradminuser' + DateTime.now().getTime() + '@testorg.com';
        // This code runs as the system user
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User u = new User(Alias = 'standt', Email='standarduser@testorg.com',
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles',
            UserName=uniqueUserName);
        insert u;
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'ClusterPac_Admin'];
        insert new PermissionSetAssignment(AssigneeId = u.id, PermissionSetId = ps.Id);
        return u;
    }

    public static User createClusterUser() {
        String uniqueUserName = 'clusteruser' + DateTime.now().getTime() + '@testorg.com';
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        //Creating cluster user
        User u = new User(Alias = 'clustu', Email='clusteruser@testorg.com',
        EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
        LocaleSidKey='en_US', ProfileId = p.Id,
        TimeZoneSidKey='America/Los_Angeles',
        UserName=uniqueUserName);
        insert u;
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'ClusterPac_User'];
        insert new PermissionSetAssignment(AssigneeId = u.id, PermissionSetId = ps.Id);
        return u;
    }

    public static User createStandardUser() {
        String uniqueUserName = 'standarduser' + DateTime.now().getTime() + '@testorg.com';
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User standarduser = new User(Alias = 'standt', Email='standarduser@testorg.com',
        EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
        LocaleSidKey='en_US', ProfileId = p.Id,
        TimeZoneSidKey='America/Los_Angeles',
        UserName=uniqueUserName);
        insert standarduser;
        return standarduser;
    }

    public static User createAdminUser() {
        String uniqueUserName = 'adminuser' + DateTime.now().getTime() + '@testorg.com';
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User standarduser = new User(Alias = 'adminu', Email='adminuser@testorg.com',
        EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
        LocaleSidKey='en_US', ProfileId = p.Id,
        TimeZoneSidKey='America/Los_Angeles',
        UserName=uniqueUserName);
        insert standarduser;
        return standarduser;
    }

    public static ClusterModelWrapper createModel(string modelJson) {
        User adminUser = createClusterAdmin();
        ClusterModelWrapper model;
        System.runAs(adminUser) {
            model = ClusterModelBuilderController.saveModel(modelJson);
        }
        return model;
    }

    public static ClusterModelWrapper createLongTextModel() {
        String modelJson = '{"algorithm":"K-Medoids","fields":[{"name":"Description","displayLabel":"Description","relationName":"","objectName":"Lead","distanceType":"LongText","weight":1},{"name":"Id","displayLabel":"Lead ID","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"Industry","displayLabel":"Industry","relationName":"","objectName":"Lead","distanceType":"Category","weight":1},{"name":"Name","displayLabel":"Full Name","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"NumberOfEmployees","displayLabel":"Employees","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1},{"name":"Title","displayLabel":"Title","relationName":"","objectName":"Lead","distanceType":"Text","weight":1}],"filter":"{\\"expressionFields\\":[],\\"customLogic\\":\\"\\"}","isCustomSoql":false,"name":"LeadsUnitTest","numberOfClusters":5,"objectName":"Lead","soql":"SELECT Description, Id, Industry, Name, NumberOfEmployees, Title FROM Lead LIMIT 20"}';
        return ClusterTestData.createModel(modelJson);
    }

    public static List<SObject> getBatchApexData(Database.Batchable<sObject> batchApexInstance) {
        // Get a query locator
        Database.QueryLocator ql = (Database.QueryLocator)batchApexInstance.start(null);
        // Get an iterator
        Database.QueryLocatorIterator it =  ql.iterator();
        List<SObject> resultScope = new List<SObject>();
        while (it.hasNext())
        {
            resultScope.add((SObject)it.next());
        }
        return resultScope;
    }

    public static String loadTextFromStaticResource(String resourceName) {
        //Looks like the only way to load a string from a static resource in a unit test is to mock an http response
        StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
        mock.setStaticResource(resourceName);
        mock.setStatusCode(200);
        mock.setHeader('Content-Type', 'application/json');
        
        // Set the mock callout mode
        Test.setMock(HttpCalloutMock.class, mock);
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://www.salesforce.com');
        req.setMethod('GET');
        Http h = new Http();
        HttpResponse res = h.send(req);
        return res.getBody();
    }
}