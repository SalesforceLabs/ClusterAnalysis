/*
 * Helper class for comparisson and distance functions
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterDataHelper {
    public class NumericFieldFunctions implements ClusterFieldFunctions {
        public Integer compare(Object compare, Object compareTo) {
            Integer result = 0;
            if (compare instanceof Integer) {
                Integer compareToInt = Integer.valueOf(compareTo);
                if ((Integer)compare == compareToInt) result = 0;
                else if ((Integer)compare > compareToInt) result = 1;
                else result = -1;
            } else if (compare instanceof Long) {
                Long compareToLong = (Long)compareTo;
                if ((Long)compare == compareToLong) result = 0;
                else if ((Long)compare > compareToLong) result = 1;
                else result = -1;
                
            } else if (compare instanceof Decimal) {
                Decimal compareToDec = (Decimal)compareTo;
                if ((Decimal)compare == compareToDec) result = 0;
                else if ((Decimal)compare > compareToDec) result = 1;
                else result = -1;
                
            } else if (compare instanceof Double) {
                Double compareToDouble = Double.valueOf(compareTo);
                if (Math.abs((Double)compare - compareToDouble) < DOUBLEEPSILON) result = 0;
                else if ((Double)compare > compareToDouble) result = 1;
                else result = -1;
                
            } else {
                throw new ClusterException('Datatype is not supported for value ' + String.valueOf(compare));
            }
            return result;
        }        
    }

    public class TextFieldFunctions implements ClusterFieldFunctions {
        public Integer compare(Object compare, Object compareTo) {
            //We will use specific compare for strings because we need max length to normalize distance
            Integer result;
            String s1 = String.valueOf(compare);
            String s2 = String.valueOf(compareTo);
            if (s1.length() > s2.length()) result = 1;
            else if (s1.length() < s2.length()) result = -1;
            else result = s1.compareTo(s2);
            return result;
        }        
    }

    public class CategoryFieldFunctions implements ClusterFieldFunctions{
        public Integer compare(Object compare, Object compareTo) {
            return String.valueOf(compare).compareTo(String.valueOf(compareTo));
        }        
    }

    public class CosineSimilarityResult {
        public Double value;
        public Double[] idf;
    }

    private static Logger log = LogFactory.getLogger();
    private static final Map<String, ClusterFieldFunctions> fieldFunctionsMap;
    private static final ClusterFieldFunctions textFieldComparer;
    private static final ClusterFieldFunctions numericFieldComparer;
    public static final Double DOUBLEEPSILON = 0.000001;
    public static final Double DOUBLE_MAX_VALUE = 9223372036854775807.0;
    public static final Double DOUBLE_ZERO = 0.0;
    public static final Double DOUBLE_ONE = 1.0;
    public static final Integer INT_ZERO = 0;

    static {
        fieldFunctionsMap = new Map<String, ClusterFieldFunctions>();
        textFieldComparer = new TextFieldFunctions();
        numericFieldComparer = new NumericFieldFunctions();
        fieldFunctionsMap.put(ClusterConstants.FIELDTYPE_NUMERIC, numericFieldComparer);
        fieldFunctionsMap.put(ClusterConstants.FIELDTYPE_TEXT, textFieldComparer);
        fieldFunctionsMap.put(ClusterConstants.FIELDTYPE_CATEGORY, new CategoryFieldFunctions());
    }

    public static Object getSObjectFieldValue(SObject record, ClusterModelFieldWrapper field){
        Object value;
        if (field.relationName != null && field.relationName != '') {
            SObject relation = record.getSObject(field.relationName);
            value = relation == null ? null : relation.get(field.name);
        }
        else {
            value = record.get(field.name);
        }
        if (value instanceof DateTime) {
            value = ((DateTime)value).getTime();  //Convert datetime to number for calculations
        }
        return value;
    }

    public static Integer compareFieldValueAbs(Object compare, Object compareTo, ClusterModelFieldWrapper field){
        Integer result = 0;
        if ((compare == null) && (compareTo == null)) result = 0;
        else if (compare == null) result = -1;
        else if (compareTo == null) result = 1;
        else {
            ClusterFieldFunctions fieldFunctions = fieldFunctionsMap.get(field.distanceType);
            if (fieldFunctions != null) result = fieldFunctions.compare(compare, compareTo);
            else if (field.isIdField) {
                return textFieldComparer.compare(String.valueOf(compare), String.valueOf(compareTo));
            }
            else result = 0;
        }
        return result;
    }

    public static void normalizeObject(Object[] currentObject, ClusterJobState jobState) {
        //TODO: implement
    }

    public static Double calculateMeanDistanceToCluster(ClusterDataPoint sourceDataPoint, Integer clusterIndex, ClusterAlgorithmRunner runner) {
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)runner.getJobState();
        return calculateMeanDistanceToCluster(sourceDataPoint, clusterIndex, runner, jobState.dataPoints);
    }

    public static Double calculateMeanDistanceToCluster(ClusterDataPoint sourceDataPoint, Integer clusterIndex, ClusterAlgorithmRunner runner, ClusterDataPoint[] sampleDataPoints) {
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)runner.getJobState();
        Integer currentClusterSize = 0;
        Double currentClusterDistance = 0;
        for (ClusterDataPoint dataPoint:sampleDataPoints) {
            if (clusterIndex == dataPoint.clusterIndex && dataPoint.recordId != sourceDataPoint.recordId) {
                currentClusterSize++;
                currentClusterDistance += runner.calculateDPDistance(sourceDataPoint, dataPoint);
            }
        }
        currentClusterDistance = (currentClusterSize > 0) ? currentClusterDistance / currentClusterSize : 0;
        return currentClusterDistance;
    }

    public static Integer findNearestCluster(ClusterDataPoint dataPoint, ClusterAlgorithmRunner runner) {
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)runner.getJobState();
        //Find nearest cluster
        Double minDistance = DOUBLE_MAX_VALUE;
        Integer nearestClusterIndex = -1;
        for (Integer i = 0; i < jobState.centroids.size(); i++) {
            Double currentDistance = runner.calculateDPDistance(dataPoint, jobState.centroids[i]);
            if ((currentDistance < minDistance) && (dataPoint.clusterIndex != i)) {
                minDistance = currentDistance;
                nearestClusterIndex = i;
            }
        }
        return nearestClusterIndex;
    }

    public static List<ClusterNeighbor> findNearestClusters(ClusterDataPoint dataPoint, Integer numNeighbors, ClusterAlgorithmRunner runner) {
        log.debug('Starting nearest clusters calculation for ' + dataPoint.externalId);
        List<ClusterNeighbor> neighbors = new List<ClusterNeighbor>();
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)runner.getJobState();
        Integer numCentroids = jobState.centroids.size();
        Double minDistance = DOUBLE_MAX_VALUE;
        //Calculating distances to all centroids and adding to the list
        for (Integer i = 0; i < numCentroids; i++) {
            ClusterNeighbor neighbor = new ClusterNeighbor();
            neighbor.distance = runner.calculateDPDistance(dataPoint, jobState.centroids[i]);
            neighbor.clusterIndex = i;
            neighbors.add(neighbor);
        }
        Integer minNeighborIndex = -1;
        Integer numIterations = Math.min(numNeighbors, numCentroids - 1);
        List<ClusterNeighbor> sortedNeighbors = new List<ClusterNeighbor>();
        //This code uses partial selection sort to find k minimum items. 
        //This should be good enough because we will be finding only 3 nearest clusters
        //TODO: Ideally this needs to be replaced with more efficient O(n) implementation
        for (Integer i = 0; i < numNeighbors; i++) {
            for (Integer j = i + 1; j < numCentroids; j++) {
                ClusterNeighbor currNeighbor = neighbors.get(j);
                if (currNeighbor.distance < minDistance) {
                    minDistance = currNeighbor.distance;
                    neighbors.set(j, neighbors.get(i));
                    neighbors.set(i, currNeighbor);
                }                
            }
            sortedNeighbors.add(neighbors.get(i));
        }
        log.debug('Found ' + sortedNeighbors.size() + ' nearest clusters');
        return sortedNeighbors;
    }

    public static Double calculateNumericGowerDistance(Double a, Double b, Double delta) {
        if (a == null && b == null) {
            return 0;
        }
        Double d = 0;
        try {
            d = Math.abs(a - b) / delta;
        }
        catch (Exception ex) {
            log.error('Exception in calculateNumericGowerDistance', ex);
            d = 1; //Set maximum distance value in case of exception
        }
        return d;
    }

    public static Double calculateTextGowerDistance(String a, String b, Integer min, Integer max) {
        if (a == null && b == null) return 0;
        Double r = max;
        Double d = 0;
        try {
            if (a == null) {
                d = Double.valueOf(b.length()) / r;
            }
            else if (b == null) {
                d = Double.valueOf(a.length()) / r;
            }
            else {
                d = Double.valueOf(a.getLevenshteinDistance(b)) / r;
            }
        }
        catch (Exception ex) {
            log.error('Exception in calculateTextGowerDistance', ex);
            d = 1; //Set maximum distance value in case of exception
        }
        return d;
    }

    public static Double calculateCategoryGowerDistance(String a, String b) {
        if (a == null && b == null) {
            return 0;
        }
        return (a == b) ? DOUBLE_ZERO : DOUBLE_ONE;
    }

    public static Double calculateGowerDistance(Object[] currentObject, Object[] centroid, ClusterJobState jobState) {
        Double distance = 0;
        Double weight = 0;
        ClusterModelWrapper model = jobState.model;
        ClusterModelFieldWrapper modelField;
        for (Integer i = 0; i < model.fields.size(); i++) {
            modelField = model.fields[i];
            if (modelField.isNumeric) {
                distance += modelField.weight * calculateNumericGowerDistance(Double.valueOf(currentObject[i]), Double.valueOf(centroid[i]), 
                    jobState.minMaxValues[i].delta);
                weight += modelField.weight;
            }
            else if (modelField.isText) {
                distance += modelField.weight * calculateTextGowerDistance(String.valueOf(currentObject[i]), String.valueOf(centroid[i]), 
                    Integer.valueOf(jobState.minMaxValues[i].minValue), Integer.valueOf(jobState.minMaxValues[i].maxValue));
                weight += modelField.weight;
            }
            else if (modelField.isCategory) {
                distance += modelField.weight * calculateCategoryGowerDistance(String.valueOf(currentObject[i]), String.valueOf(centroid[i]));
                weight += modelField.weight;
            }
            else if (modelField.isLongText) {
                distance += modelField.weight * calculateCosineDistance(currentObject[i], centroid[i], jobState.minMaxValues[i]);
                weight += modelField.weight;
            }
        }
        return distance / weight;
    }

    public static Double calculateEuclideanDistance(Object[] currentObject, Object[] centroid, ClusterJobState jobState) {
        Double sumDistance = 0;
        ClusterModelWrapper model = jobState.model;
        for (Integer i = 0; i < model.fields.size(); i++) {
            if (model.fields[i].isNumeric) {
                try {
                    Double distance = model.fields[i].weight *  ClusterDataHelper.calculateNumericGowerDistance(Double.valueOf(currentObject[i]), Double.valueOf(centroid[i]), jobState.minMaxValues[i].delta);
                    sumDistance += distance * distance;
                }
                catch (Exception ex) 
                {
                    log.error('Exception in calculateEuclideanDistance', ex);
                    // Let's just log and swallow null values or division by zero for now
                } 
            }
            else if (model.fields[i].isLongText) {
                //For euclidean distance we will calculate cosine distance for long text and emulate dot product
                //TODO: Consider throwing a model validation exception if Euclidean distance is used with LongText
                Object tf1 = currentObject[i];
                Object tf2 = centroid[i];
                Double distance = model.fields[i].weight * calculateCosineDistance(tf1, tf2, jobState.minMaxValues[i]);
                sumDistance += distance * distance;
            }
        }
        return Math.sqrt(sumDistance);
    }

    public static Double calculateManhattanDistance(Object[] currentObject, Object[] centroid, ClusterJobState jobState) {
        //Numeric part of Gower distance uses Manhattan algorithm
        return calculateGowerDistance(currentObject, centroid, jobState);
    }

    public static Double calculateCosineDistance(Object vector1, Object vector2, ClusterMinMaxValue minMax) {
        if ((vector1 == null) && (vector2 == null)) {
            return DOUBLE_ZERO;
        }
        else if ((vector1 == null) || (vector2 == null)) {
            return DOUBLE_ONE;
        }
        ClusterCompressedDoubleArray tf1i = (ClusterCompressedDoubleArray)vector1;
        ClusterCompressedDoubleArray tf2i = (ClusterCompressedDoubleArray)vector2;
        Double cosineSimilarity;
        if (minMax == null) {
            Double[] idf = null;
            cosineSimilarity = calculateCosineSimilarity(tf1i, tf2i, idf);
        }
        else if (minMax.vector == null) {
            Object idfVector = minMax.maxValue;        
            ClusterCompressedDoubleArray idfi = idfVector == null ? null : (ClusterCompressedDoubleArray)idfVector;
            CosineSimilarityResult csResult = calculateCosineSimilarity(tf1i, tf2i, idfi);
            cosineSimilarity = csResult.value;
            minMax.vector = csResult.idf; //Cache uncompressed idf for faster calculations
        }
        else {
            cosineSimilarity = calculateCosineSimilarity(tf1i, tf2i, minMax.vector);
        }
        return DOUBLE_ONE - cosineSimilarity;
    }   

    public static Double calculateCosineSimilarity(ClusterCompressedDoubleArray vector1, ClusterCompressedDoubleArray vector2, Double[] idfVector) {
        //We will also use idf vector in calculations to optimize loops a little        
        Double dotProduct = DOUBLE_ZERO;
        Double magnitude1 = DOUBLE_ZERO;
        Double magnitude2 = DOUBLE_ZERO;
        //Vector sizes might be different
        //The code below is extracted from ClusterCompressedDoubleArray.ClusterCompressedDoubleArrayIterator code and copy/pasted 3 times
        //This is proven to be about 3 times faster than using custom iterators hasNext/next or moveNext/getValue
        //Apparently apex method calls are very expensive, therefore they were replaced by this ugly code
        Integer v1ArrayIndex = 0, v1ValueIndex = 0, v2ArrayIndex = 0, v2ValueIndex = 0, idfArrayIndex = 0;
        Integer v1Size = vector1.size(), v2Size = vector2.size(), idfSize = idfVector == null ? 0 : idfVector.size();
        ClusterCompressedDoubleArray.ClusterCompressedDouble v1Value = null, v2Value = null, idfValue = null;
        List<ClusterCompressedDoubleArray.ClusterCompressedDouble> v1List = vector1.getCompressedList();
        List<ClusterCompressedDoubleArray.ClusterCompressedDouble> v2List = vector2.getCompressedList(); 
        Boolean v1hasNext = v1Size > 0;
        Boolean v2hasNext = v2Size > 0;
        Boolean idfHasNext = idfSize > 0;
        Boolean v1zero = false, v2zero = false;
        while (v1hasNext || v2hasNext) {
            Double v1;
            if (v1Value != null) {
                v1 = v1Value.value;
                v1zero = ((v1 - DOUBLE_ZERO) < DOUBLEEPSILON);
            }
            else if (v1hasNext) {
                v1Value = v1List[v1ArrayIndex];
                v1ValueIndex = 0;
                v1 = v1Value.value;
                v1zero = ((v1 - DOUBLE_ZERO) < DOUBLEEPSILON);
            }
            else {
                v1 = DOUBLE_ZERO;
                v1zero = true;
            }

            Double v2;
            if (v2Value != null) {
                v2 = v2Value.value;
                v2zero = ((v2 - DOUBLE_ZERO) < DOUBLEEPSILON);
            }
            else if (v2hasNext) {
                v2Value = v2List[v2ArrayIndex];
                v2ValueIndex = 0;
                v2 = v2Value.value;
                v2zero = ((v2 - DOUBLE_ZERO) < DOUBLEEPSILON);
            }
            else {
                v2 = DOUBLE_ZERO;
                v2zero = true;
            }

            //If both values are zeros no need to calculate the magnitude and dot product
            if (v1zero && v2zero) {
                //Fast forward to the next non zero value if both values are zeros
                //TF vectors are sparse, there will be a lot of zeros
                Integer skipCount;
                if (v1Value == null && v2Value == null) {
                    //Looks like this is the end
                    break;
                }
                else if (v1Value == null) {
                    skipCount = v2Value.count - v2ValueIndex;
                    v2ValueIndex = -1;
                    v2Value = null;
                    v2ArrayIndex++;
                }
                else if (v2Value == null) {
                    skipCount = v1Value.count - v1ValueIndex;
                    v1ValueIndex = -1;
                    v1Value = null;
                    v1ArrayIndex++;
                }
                else {
                    Integer v1ZeroCount = v1Value.count - v1ValueIndex;
                    Integer v2ZeroCount = v2Value.count - v2ValueIndex;
                    if (v1ZeroCount > v2ZeroCount) {
                        skipCount = v2ZeroCount;
                        v1ValueIndex += skipCount;
                        v2Value = null;
                        v2ValueIndex = -1;
                        v2ArrayIndex++;
                    }
                    else if (v1ZeroCount < v2ZeroCount) {
                        skipCount = v1ZeroCount;
                        v2ValueIndex += skipCount;
                        v1Value = null;
                        v1ValueIndex = -1;
                        v1ArrayIndex++;
                    }
                    else {
                        skipCount = v1ZeroCount;
                        v2Value = null;
                        v2ValueIndex = -1;
                        v2ArrayIndex++;
                        v1Value = null;
                        v1ValueIndex = -1;
                        v1ArrayIndex++;
                    }
                }
                if (idfHasNext) {
                    idfArrayIndex += skipCount;
                }
                v1HasNext = v1ArrayIndex < v1Size;
                v2HasNext = v2ArrayIndex < v2Size;
                idfHasNext = idfArrayIndex < idfSize;
                continue;
            }

            if (idfHasNext) {
                Double idf = idfVector[idfArrayIndex];
                //Actual calculations
                v1 = v1 * idf;
                v2 = v2 * idf;
                //Moving to the next idf value
                idfArrayIndex++;
                idfHasNext = idfArrayIndex < idfSize;
            }
            dotProduct += v1 * v2;
            magnitude1 += v1 * v1;
            magnitude2 += v2 * v2;
            //Moving to the next v1
            if (v1hasNext) {
                if (v1Value != null) {
                    if (v1ValueIndex < v1Value.count - 1) {
                        v1ValueIndex++;
                    }
                    else {
                        v1Value = null;
                        v1ValueIndex = -1;
                        v1ArrayIndex++;
                    }
                }
                else {
                    v1ArrayIndex++;
                }
                v1HasNext = v1ArrayIndex < v1Size;
            }
            //Moving to the next v2
            if (v2hasNext) {
                if (v2Value != null) {
                    if (v2ValueIndex < v2Value.count - 1) {
                        v2ValueIndex++;
                    }
                    else {
                        v2Value = null;
                        v2ValueIndex = -1;
                        v2ArrayIndex++;
                    }
                }
                else {
                    v2ArrayIndex++;
                }
                v2HasNext = v2ArrayIndex < v2Size;
            }
        }
        v1zero = (magnitude1 - DOUBLE_ZERO) < DOUBLEEPSILON;
        v2zero = (magnitude2 - DOUBLE_ZERO) < DOUBLEEPSILON;
        if (!v1zero && !v2zero) {
            return dotProduct / Math.sqrt(magnitude1 * magnitude2);
        }
        else if (v1zero && v2zero) {
            return DOUBLE_ONE; //If both vectors are zero we consider them equal
        }
        else {
            return DOUBLE_ZERO; //If one of the vectors is non zero the similarity is 0 - completely different
        }
    }

    public static CosineSimilarityResult calculateCosineSimilarity(ClusterCompressedDoubleArray vector1, ClusterCompressedDoubleArray vector2, ClusterCompressedDoubleArray idfVector) {
        //We will also use idf vector in calculations to optimize loops a little
        CosineSimilarityResult result = new CosineSimilarityResult();
        Double dotProduct = DOUBLE_ZERO;
        Double magnitude1 = DOUBLE_ZERO;
        Double magnitude2 = DOUBLE_ZERO;
        //Vector sizes might be different
        //The code below is extracted from ClusterCompressedDoubleArray.ClusterCompressedDoubleArrayIterator code and copy/pasted 3 times
        //This is proven to be about 3 times faster than using custom iterators hasNext/next or moveNext/getValue
        //Apparently apex method calls are very expensive, therefore they were replaced by this ugly code
        Integer v1ArrayIndex = 0, v1ValueIndex = 0, v2ArrayIndex = 0, v2ValueIndex = 0, idfArrayIndex = 0, idfValueIndex = 0;
        Integer v1Size = vector1.size(), v2Size = vector2.size(), idfSize = idfVector == null ? 0 : idfVector.size();
        List<Double> idfDecompressed = new List<Double>();
        ClusterCompressedDoubleArray.ClusterCompressedDouble v1Value = null, v2Value = null, idfValue = null;
        List<ClusterCompressedDoubleArray.ClusterCompressedDouble> v1List = vector1.getCompressedList();
        List<ClusterCompressedDoubleArray.ClusterCompressedDouble> v2List = vector2.getCompressedList(); 
        List<ClusterCompressedDoubleArray.ClusterCompressedDouble> idfList = idfVector == null ? null : idfVector.getCompressedList();
        Boolean v1hasNext = v1Size > 0;
        Boolean v2hasNext = v2Size > 0;
        Boolean idfHasNext = idfSize > 0;
        while (v1hasNext || v2hasNext || idfHasNext) {
            Double v1;
            if (v1Value != null) {
                v1 = v1Value.value;
            }
            else if (v1hasNext) {
                v1Value = v1List[v1ArrayIndex];
                v1ValueIndex = 0;
                v1 = v1Value.value;
            }
            else {
                v1 = DOUBLE_ZERO;
            }

            Double v2;
            if (v2Value != null) {
                v2 = v2Value.value;
            }
            else if (v2hasNext) {
                v2Value = v2List[v2ArrayIndex];
                v2ValueIndex = 0;
                v2 = v2Value.value;
            }
            else {
                v2 = DOUBLE_ZERO;
            }

            if (idfHasNext) {
                Double idf;
                //Getting current idf value
                if (idfValue != null) {
                    idf = idfValue.value;
                }
                else if (idfHasNext) {
                    idfValue = idfList[idfArrayIndex];
                    idfValueIndex = 0;
                    idf = idfValue.value;
                }
                else {
                    idf = DOUBLE_ZERO;
                }
                idfDecompressed.add(idf);
                //Actual calculations
                v1 = v1 * idf;
                v2 = v2 * idf;
                //Moving to the next idf value
                if (idfValue != null) {
                    if (idfValueIndex < idfValue.count - 1) {
                        idfValueIndex++;
                    }
                    else {
                        idfValue = null;
                        idfValueIndex = -1;
                        idfArrayIndex++;
                    }
                }
                else {
                    idfArrayIndex++;
                }
                idfHasNext = idfArrayIndex < idfSize;
            }
            if (v1hasNext || v2hasNext) {
                dotProduct += v1 * v2;
                magnitude1 += v1 * v1;
                magnitude2 += v2 * v2;
            }
            //Moving to the next v1
            if (v1hasNext) {
                if (v1Value != null) {
                    if (v1ValueIndex < v1Value.count - 1) {
                        v1ValueIndex++;
                    }
                    else {
                        v1Value = null;
                        v1ValueIndex = -1;
                        v1ArrayIndex++;
                    }
                }
                else {
                    v1ArrayIndex++;
                }
                v1HasNext = v1ArrayIndex < v1Size;
            }
            //Moving to the next v2
            if (v2hasNext) {
                if (v2Value != null) {
                    if (v2ValueIndex < v2Value.count - 1) {
                        v2ValueIndex++;
                    }
                    else {
                        v2Value = null;
                        v2ValueIndex = -1;
                        v2ArrayIndex++;
                    }
                }
                else {
                    v2ArrayIndex++;
                }
                v2HasNext = v2ArrayIndex < v2Size;
            }
        }
        Boolean v1zero = (magnitude1 - DOUBLE_ZERO) < DOUBLEEPSILON;
        Boolean v2zero = (magnitude2 - DOUBLE_ZERO) < DOUBLEEPSILON;
        if (!v1zero && !v2zero) {
            result.value = dotProduct / Math.sqrt(magnitude1 * magnitude2);
        }
        else if (v1zero && v2zero) {
            result.value = DOUBLE_ONE; //If both vectors are zero we consider them equal
        }
        else {
            result.value = DOUBLE_ZERO; //If one of the vectors is non zero the similarity is 0 - completely different
        }
        result.idf = idfDecompressed;
        return result;
    }

    public static Double calculateCosineSimilarity(Double[] vector1, Double[] vector2, Double[] idfVector) {
        //We will also use idf vector in calculations to optimize loops a little
        Double dotProduct = 0.0;
        Double magnitude1 = 0.0;
        Double magnitude2 = 0.0;
        Double zero = 0.0;
        //Vector sizes might be different
        Integer v1Size = vector1.size();
        Integer v2Size = vector2.size();
        Integer idfSize = idfVector.size();
        Integer length = Math.max(v1Size, v2Size);
        for (Integer i = 0; i < length; i++) {
            Double v1 = i < v1Size ? vector1[i] : zero;
            Double v2 = i < v2Size ? vector2[i] : zero;
            if ((idfVector != null) && i < idfSize) {
                Double idf = idfVector[i];
                v1 = v1 * idf;
                v2 = v2 * idf;
            }
            dotProduct += v1 * v2;
            magnitude1 += v1 * v1;
            magnitude2 += v2 * v2;
        }
        magnitude1 = Math.sqrt(magnitude1);
        magnitude2 = Math.sqrt(magnitude2);
        Double magnitude = magnitude1 * magnitude2;
        if (doublesEqual(magnitude, zero)) {
            return 1.0;
        }
        else {
            return dotProduct / magnitude;
        }
    }

    public static Integer getRandomInt(Integer min, Integer max) {
        return Math.round(Math.random() * (max - min) + min);
    }

    public static ClusterDataPoint[] getRandomDataPoints(Integer count, ClusterJobState jobState) {
        ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterJobResult__c);
        //isAccessible permission is checked in ClusterAccessCheck.checkReadPermission, exception is thrown in case of no access
        Database.QueryLocator randomRecordLocator = Database.getQueryLocator([SELECT Id, Cluster__c, Json__c, Json2__c, Json3__c, Json4__c, Json5__c, RecordId__c, RecordName__c, ClusterNumber__c, ClusterJob__c, DistanceToCluster__c, DistanceToNNCluster__c 
            FROM ClusterJobResult__c WHERE ClusterJob__c = :jobState.clusterJob.Id ORDER BY Random__c LIMIT :count]);
        
        return getDataPoints(randomRecordLocator, jobState);
    }

    public static ClusterDataPoint[] getDataPoints(List<Id> dataPointIds, ClusterJobState jobState) {
        Database.QueryLocator resultLocator = Database.getQueryLocator([SELECT Id, Cluster__c, Json__c, Json2__c, Json3__c, Json4__c, Json5__c, RecordId__c, RecordName__c, ClusterNumber__c, ClusterJob__c, DistanceToCluster__c, DistanceToNNCluster__c 
            FROM ClusterJobResult__c WHERE Id IN :dataPointIds WITH SECURITY_ENFORCED]);
        return ClusterDataHelper.getDataPoints(resultLocator, jobState);
    }

    public static ClusterDataPoint[] getDataPoints(Database.QueryLocator dpLocator, ClusterJobState jobState) {
        List<ClusterDataPoint> dataPoints = new List<ClusterDataPoint>();
        ClusterObjectFactory objectFactory = new ClusterObjectFactory();
        ClusterSObjectProcessor objectProcessor = objectFactory.createSObjectProcessor(jobState, false); //No compression for javascript
        Database.QueryLocatorIterator dpRecordIterator = dpLocator.iterator();
 
        // Iterate over the records
        while (dpRecordIterator.hasNext())
        {
            ClusterJobResult__c record = (ClusterJobResult__c)dpRecordIterator.next();
            ClusterDataPoint dp = objectProcessor.createDataPointFromResult(record);
            dataPoints.add(dp);
        }
        return dataPoints;
    }

    public static ClusterDataPoint[] getDataPoints(ClusterJobResult__c[] jobResults, ClusterJobState jobState) {
        Integer index=0;
        List<ClusterDataPoint> dataPoints = new List<ClusterDataPoint>();
        ClusterObjectFactory objectFactory = new ClusterObjectFactory();
        ClusterSObjectProcessor objectProcessor = objectFactory.createSObjectProcessor(jobState, false); //No compression for javascript
 
        // Iterate over the records
        for (ClusterJobResult__c record : jobResults)
        {
            ClusterDataPoint dp = objectProcessor.createDataPointFromResult(record);
            dataPoints.add(dp);
        }
        return dataPoints;
    }


    public static void populateClusterJobResultJsonValues(ClusterJobResult__c result, String json) {
        Integer fieldSize = ClusterConstants.getMaxJsonFieldSize();
        populateClusterJobResultJsonValues(result, json, fieldSize);
    }

    public static void populateClusterJobResultJsonValues(ClusterJobResult__c result, String json, Integer fieldSize) {
        clearClusterJobResultJsonValues(result);
        if (json != null && json.length() > fieldSize) {
            Integer startIndex = 0;
            Integer fieldBank = 1;
            while (startIndex < json.length()) {
                String resultPart = json.mid(startIndex, fieldSize);
                populateClusterJobResultJsonValueBank(result, fieldBank, resultPart);
                fieldBank++;
                startIndex += fieldSize;
            }
        }
        else {
            result.Json__c = json;
        }
    }

    public static void clearClusterJobResultJsonValues(ClusterJobResult__c result) {
        result.Json__c = null;
        result.Json2__c = null;
        result.Json3__c = null;
        result.Json4__c = null;
        result.Json5__c = null;
    }

    public static void populateClusterJobResultJsonValueBank(ClusterJobResult__c result, Integer fieldIndex, String json) {
        //This looks lame but not sure how the namespace will be resolved if we use dynamic binding (via set)
        switch on fieldIndex {
            when 1 {
                result.Json__c = json;
            }
            when 2 {
                result.Json2__c = json;
            }
            when 3 {
                result.Json3__c = json;
            }
            when 4 {
                result.Json4__c = json;
            }
            when 5 {
                result.Json5__c = json;
            }
            when else {
                throw new ClusterException('Invalid json field bank index ' + fieldIndex);
            }
        }
    }

    public static String getClusterJobResultValues(ClusterJobResult__c jobResult) {
        String result = jobResult.Json__c;
        if (!stringIsNullOrEmpty(result)) {
            //This looks lame but not sure how the namespace will be resolved if we use dynamic binding (via get)
            String nextResult = jobResult.Json2__c;
            if (!stringIsNullOrEmpty(nextResult)) {
                result += nextResult;
            }
            else {
                return result;
            }
            nextResult = jobResult.Json3__c;
            if (!stringIsNullOrEmpty(nextResult)) {
                result += nextResult;
            }
            else {
                return result;
            }
            nextResult = jobResult.Json4__c;
            if (!stringIsNullOrEmpty(nextResult)) {
                result += nextResult;
            }
            else {
                return result;
            }
            nextResult = jobResult.Json5__c;
            if (!stringIsNullOrEmpty(nextResult)) {
                result += nextResult;
            }
            else {
                return result;
            }
        }
        return result;
    }

    public static Boolean stringIsNullOrEmpty(String s) {
        return (s == null) || (s == '');
    }

    public static Boolean doublesEqual(Double a, Double b) {
        return Math.abs(a-b) < DOUBLEEPSILON;
    }

    public static Integer compareDoubles(Double compare, Double compareTo) {
        Integer result = 0;
        if ((compare == null) && (compareTo == null)) result = 0;
        else if (compare == null) result = -1;
        else if (compareTo == null) result = 1;
        else {            
            if (Math.abs(compare - compareTo) < DOUBLEEPSILON) result = 0;
            else if (compare > compareTo) result = 1;
            else result = -1;
        }
        return result;
    }

    public static Integer compareStrings(String compare, String compareTo) {
        Integer result = 0;
        if ((compare == null) && (compareTo == null)) result = 0;
        else if (compare == null) result = -1;
        else if (compareTo == null) result = 1;
        else {            
            result = compare.compareTo(compareTo);
        }
        return result;
    }

    public static Double asDouble(Object value) {
        if (value == null) {
            return 0.0;
        }
        return Double.valueOf(value);
    }
}