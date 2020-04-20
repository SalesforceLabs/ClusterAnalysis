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
}
