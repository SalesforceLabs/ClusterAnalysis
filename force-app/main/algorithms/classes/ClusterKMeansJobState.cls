/*
 * State of K-Means algorithm
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterKMeansJobState extends ClusterJobState {
    public List<ClusterDataPoint> centroids;
    public List<Integer> nearestCentroids;
    public List<ClusterDataPoint> dataPoints;
    public Map<String, Integer> dataPointsIdMap;
    public Boolean hasAssignmentChanged;
    public Boolean hasSwapped;
    public List<Id> sampleResultsIds;
    public Integer iterationsCount;

    public ClusterKMeansJobState() {
        this.centroids = new List<ClusterDataPoint>();
        this.hasAssignmentChanged = false;
        this.hasSwapped = false;
        this.iterationsCount = 0;
    }

    public override void loadFromMap(Map<String, Object> stateValues) {
        super.loadFromMap(stateValues);
        this.iterationsCount = (Integer)stateValues.get('iterationsCount');
        this.centroids = this.loadDataPointList((Object[])stateValues.get('centroids'));
        this.dataPoints = this.loadDataPointList((Object[])stateValues.get('dataPoints'));
        Object[] resultIdList = (Object[])stateValues.get('sampleResultsIds');
        if (resultIdList != null) {
            this.sampleResultsIds = new List<Id>();
            for (Object idValue:resultIdList) {
                this.sampleResultsIds.add(Id.valueOf((String)idValue));
            }
        }
        List<Object> nearestCentroidsList = (List<Object>)stateValues.get('nearestCentroids');
        if (nearestCentroids != null) {
            this.nearestCentroids = new List<Integer>();
            for (Object nc:nearestCentroidsList) {
                this.nearestCentroids.add(Integer.valueOf(nc));
            }
        }
        else {
            this.nearestCentroids = null;
        }
    }

    private List<ClusterDataPoint> loadDataPointList(Object[] values) {
        List<ClusterDataPoint> dataPoints = new List<ClusterDataPoint>();
        if (values != null) {
            for (Object dpValue:values) {
                ClusterDataPoint dp = new ClusterDataPoint();
                dp.loadFromMap((Map<String, Object>)dpValue);
                dataPoints.add(dp);
            }
        }
        return dataPoints;
    }

    public Integer getNextClusterIndex(Integer clusterIndex) {
        Integer nextClusterIndex;
        if (this.hasNearestCentroids()) {
            //If nearest centroids were calculated take the nearest centroid to the current
            nextClusterIndex = this.nearestCentroids[clusterIndex];
        }
        else {
            //If not take the next one
            nextClusterIndex = clusterIndex + 1;
            if (nextClusterIndex >= this.centroids.size()) {
                nextClusterIndex = 0;
            }
        }
        return nextClusterIndex;
    }

    public boolean hasNearestCentroids() {
        if (this.nearestCentroids != null) {
            Boolean hasNC = true;
            for (Integer nnIndex:this.nearestCentroids) {
                hasNC = hasNC && ((nnIndex != null) && nnIndex > -1);
                if (!hasNC) {
                    break;
                }
            }
            return hasNC;
        }
        return false;
    }
    
}