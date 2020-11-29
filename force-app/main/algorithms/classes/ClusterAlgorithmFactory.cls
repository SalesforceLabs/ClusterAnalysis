/*
 * Algorithm factory - creates algorithm runners
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterAlgorithmFactory {
    public static List<UiSelectOption> getAlgorithmList() {
        //TODO: move this to some settings class, possibly create custom setings
        List<UiSelectOption> values = new List<UiSelectOption>();
        values.add(new UiSelectOption(ClusterConstants.ALGORITHM_KMEDOIDS, ClusterConstants.ALGORITHM_KMEDOIDS ));
        values.add(new UiSelectOption(ClusterConstants.ALGORITHM_KMEANS, ClusterConstants.ALGORITHM_KMEANS ));
        return values;
    }

    public static ClusterAlgorithmRunner getRunner(ClusterModelWrapper model) {
        return getRunner(model.algorithm);
    }

    public static ClusterAlgorithmRunner getRunner(String algorithm) {
        if (algorithm == ClusterConstants.ALGORITHM_KMEDOIDS) {
            return new ClusterKMedoidsPAMRunner();
        }
        else if (algorithm == ClusterConstants.ALGORITHM_KMEANS) {
            return new ClusterKMeansRunner();
        }
        else {
            throw new ClusterException(algorithm + ' algorithm is not supported');
        }
    }

    public static ClusterAlgorithmRunner getRunnerFromJobId(Id jobId) {
        List<ClusterJob__c> jobRecords = [SELECT Id, JobName__c, ClusterModel__c, ClusterModel__r.Algorithm__c, NumberOfClusters__c, ObjectName__c, JobStatus__c, JobStatusText__c, StartDate__c, EndDate__c, InternalJobId__c, Score__c 
            FROM ClusterJob__c WHERE Id = :jobId WITH SECURITY_ENFORCED];
        if (jobRecords.size() != 1) {
            throw new ClusterException('Cannot find cluster job with id ' + jobId);
        }
        ClusterJob__c job = jobRecords.get(0);        
        ClusterAlgorithmRunner runner = ClusterAlgorithmFactory.getRunner(job.ClusterModel__r.Algorithm__c);
        String jobStateJson = ClusterJobManager.loadJobState(jobId);
        runner.setJobState(jobStateJson);
        return runner;
    }
}