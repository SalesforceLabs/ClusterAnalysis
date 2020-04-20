@isTest
public with sharing class ClusterPostInstallHandlerTest {
    @isTest
    static void testInstallScript() {
        User clusterAdmin = ClusterTestData.createClusterAdmin();
        System.runAs(clusterAdmin) {
            ClusterPostInstallHandler postinstall = new ClusterPostInstallHandler();
            Test.testInstall(postinstall, null);
            Test.testInstall(postinstall, new Version(1,0), true);
            Integer modelCount = [SELECT Count() FROM ClusterModel__c];
            System.assertEquals(3, modelCount, 'Example models were not created successfully');
        }
    }
}
