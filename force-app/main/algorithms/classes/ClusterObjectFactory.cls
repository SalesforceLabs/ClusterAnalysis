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
            String[] classNameSplit = customPreprocessorApexClassName.split('.');
            String namespace;
            String className;
            if (classNameSplit.size() >= 2) {
                namespace = classNameSplit[0];
                className = classNameSplit[1];
                if (classNameSplit.size() == 3) {
                    className += '.' + classNameSplit[2];
                }
            }
            else {
                namespace = '';
                className = customPreprocessorApexClassName;
            }
            Type customApexPreprocessorType = Type.forName(namespace, customPreprocessorApexClassName);
            recordPreprocessor = (ClusterRecordPreprocessor)customApexPreprocessorType.newInstance();
        }
        else {
            recordPreprocessor = null;
        }
        return recordPreprocessor;
    }

}
