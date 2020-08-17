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
}
