/*
 * Cluster object factory class
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterObjectFactory {
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

}
