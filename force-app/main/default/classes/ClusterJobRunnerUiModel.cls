/*
 * UI model for Run Model quick action
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterJobRunnerUiModel {
    public ClusterJobRunnerUiModel() {

    }
    @AuraEnabled
    public List<ClusterModelWrapper> models;
    @AuraEnabled
    public Map<String, List<ClusterAlgorithmParameter>> parameters;
}