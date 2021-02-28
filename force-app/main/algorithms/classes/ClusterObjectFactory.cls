/*
 * Cluster object factory class
 *
 * @author: Iskander Mukhamedgaliyev
 */
public virtual with sharing class ClusterObjectFactory {
    public virtual ClusterSObjectProcessor createSObjectProcessor(ClusterJobState state) {
        return this.createSObjectProcessor(state, true);
    }

    public virtual ClusterSObjectProcessor createSObjectProcessor(ClusterJobState state, Boolean useCompression) {
        ClusterSObjectProcessor sop = new ClusterSObjectProcessor(state);
        sop.setCompression(useCompression);
        return sop;
    }

    public virtual ClusterKNNPredictor createPredictor(ClusterAlgorithmRunner runner) {
        return new ClusterKNNPredictor(runner);
    }

    public virtual ClusterRecordPreprocessor createRecordPreprocessor() {
        String customPreprocessorApexClassName = ClusterConstants.getApexRecordPreprocessorClassName();
        return this.createRecordPreprocessor(customPreprocessorApexClassName);
    }

    public virtual ClusterRecordPreprocessor createRecordPreprocessor(String customPreprocessorApexClassName) {
        ClusterRecordPreprocessor recordPreprocessor;
        if (String.isNotBlank(customPreprocessorApexClassName)) {
            Type customApexPreprocessorType = Type.forName(customPreprocessorApexClassName);
            recordPreprocessor = (ClusterRecordPreprocessor)customApexPreprocessorType.newInstance();
        }
        else {
            recordPreprocessor = null;
        }
        return recordPreprocessor;
    }

}
