public with sharing class ClusterPredictionResult {
    public class FieldValuePrediction implements Comparable {
        @AuraEnabled
        public Object value;
        @AuraEnabled
        public Double probability;
        @AuraEnabled
        public Integer numberOfSamples;

        public Integer compareTo(Object compareTo) {
            FieldValuePrediction other = (FieldValuePrediction)compareTo;
            //Order by probability desc 
            return -1 * ClusterDataHelper.compareDoubles(this.probability, other.probability);
        }
    }
    public class FieldPrediction {
        Map<String,FieldValuePrediction> fieldValuePredictionsMap;
        @AuraEnabled
        public ClusterModelFieldWrapper field;
        @AuraEnabled
        public Boolean isNumeric;
        @AuraEnabled
        public List<FieldValuePrediction> fieldValuePredictions {
            get {
                List<FieldValuePrediction> pvList = this.fieldValuePredictionsMap.values();
                pvList.sort();
                if (ClusterConstants.MAX_PREDICTION_VALUES < pvList.size()) {
                    List<FieldValuePrediction> pvListTruncated = new List<FieldValuePrediction>();
                    for (Integer i=0; i<ClusterConstants.MAX_PREDICTION_VALUES; i++) {
                        pvListTruncated.add(pvList.get(i));
                    }
                    return pvListTruncated;
                }
                else {
                    return pvList;
                }
            }
        }


        public FieldPrediction() {
            this.fieldValuePredictionsMap = new Map<String,FieldValuePrediction>();
        }

        public void addPredictionStringValue(String value, Double probability) {
            this.isNumeric = false;
            FieldValuePrediction fvPrediction = this.fieldValuePredictionsMap.get(value);
            if (fvPrediction == null) {
                fvPrediction = new FieldValuePrediction();
                fvPrediction.value = value;
                fvPrediction.numberOfSamples = 1;
                fvPrediction.probability = probability;
                this.fieldValuePredictionsMap.put(value, fvPrediction);
            }
            else {
                fvPrediction.numberOfSamples++;
                //Take the max probability
                if (fvPrediction.probability < probability) {
                    fvPrediction.probability = probability;
                }
            }
        }

        public void addPredictionDoubleValue(Double value, Double probability) {
            this.isNumeric = true;
            FieldValuePrediction fvPrediction = this.fieldValuePredictionsMap.get('value');
            if (fvPrediction == null) {
                fvPrediction = new FieldValuePrediction();
                fvPrediction.value = value;
                fvPrediction.numberOfSamples = 1;
                fvPrediction.probability = probability;
                this.fieldValuePredictionsMap.put('value', fvPrediction);
            }
            else {
                fvPrediction.value = (Double)fvPrediction.value + value;
                fvPrediction.numberOfSamples++;
                //Take the max probability
                fvPrediction.probability += probability;
            }
        }

        public void aggregateValues(Integer numNeighbors) {
            if (this.isNumeric) {
                FieldValuePrediction fvPrediction = this.fieldValuePredictionsMap.get('value');
                fvPrediction.value = Double.valueOf(fvPrediction.value) / Double.valueOf(fvPrediction.numberOfSamples);
                fvPrediction.probability = fvPrediction.probability / Double.valueOf(fvPrediction.numberOfSamples);
                //Calculate weighted probability
                fvPrediction.probability = fvPrediction.probability * Double.valueOf(fvPrediction.numberOfSamples) / Double.valueOf(numNeighbors);
            }
            else {
                for (FieldValuePrediction fvPrediction:this.fieldValuePredictionsMap.values()) {
                    //Calculate weighted probability
                    fvPrediction.probability = fvPrediction.probability * Double.valueOf(fvPrediction.numberOfSamples) / Double.valueOf(numNeighbors);
                }
            }
        }

    }
    @AuraEnabled
    public List<FieldPrediction> fieldPredictions;
    @AuraEnabled
    public List<ClusterDataPointNeighbor> nearestNeighbors;
    @AuraEnabled
    public FieldPrediction clusterPrediction;
    @AuraEnabled
    public Integer clusterIndex;
    @AuraEnabled
    public ClusterDataPoint dataPoint;


    public ClusterPredictionResult() {
        this.fieldPredictions = new List<FieldPrediction>();
    }
}
