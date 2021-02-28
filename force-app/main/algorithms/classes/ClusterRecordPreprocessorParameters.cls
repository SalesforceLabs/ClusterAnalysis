/*
 * Parameters for ClusterRecordPreprocessor
 *
 * @author: Iskander Mukhamedgaliyev
 */
global inherited sharing class ClusterRecordPreprocessorParameters {
    private Id modelId;
    private String modelName;
    private Id jobId;
    private Boolean isLearning;

    public ClusterRecordPreprocessorParameters() {

    }

    global Id getModelId() {
        return this.modelId;
    }

    public void setModelId(Id modelId) {
        this.modelId = modelId;
    }

    global String getModelName() {
        return this.modelName;
    }

    public void setModelName(String modelName) {
        this.modelName = modelName;
    }

    global Id getJobId() {
        return this.jobId;
    }

    public void setJobId(Id jobId) {
        this.jobId = jobId;
    }

    global Boolean getIsLearning() {
        return this.isLearning;
    }

    public void setIsLearning(Boolean isLearning) {
        this.isLearning = isLearning;
    }

}
