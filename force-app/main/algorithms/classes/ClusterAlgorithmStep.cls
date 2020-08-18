/*
 * Interface for cluster algorithm steps
 *
 * @author: Iskander Mukhamedgaliyev
 */
public interface ClusterAlgorithmStep {
    void init(ClusterAlgorithmRunner runner);
    void run();
    void done();
    Boolean isAsync();
}