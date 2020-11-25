/*
 * State of K-Means algorithm
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterKMeansJobState extends ClusterJobState {
    public List<ClusterDataPoint> centroids;
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
    
}