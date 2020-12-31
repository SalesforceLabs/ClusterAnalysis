/*
 * Compressed array of doubles to store TF-IDF arrays. Uses Run Length Encoding compression algorithm
 *
 * @author: Iskander Mukhamedgaliyev
 */
global with sharing class ClusterCompressedDoubleArray {
    global class ClusterCompressedDouble {
        @AuraEnabled        
        public Integer count;
        @AuraEnabled
        public Double value;

        global ClusterCompressedDouble() {

        }

        global ClusterCompressedDouble(Double doubleValue) {
            this.value = doubleValue;
            this.count = 1;
        }

        global Integer getCount() {
            return this.count;
        }

        global void setCount(Integer newCount) {
            this.count = newCount;
        }

        global Double getValue() {
            return this.value;
        }

        global void setValue(Double newValue) {
            this.value = newValue;
        }
    }

    global class ClusterCompressedDoubleArrayIterator implements Iterator<Double> {
        private ClusterCompressedDoubleArray iterableArray;
        private Integer currentArrayIndex;
        private Integer currentValueIndex;
        private ClusterCompressedDouble currentCompressedValue;
        private Integer nextArrayIndex;
        private Integer nextValueIndex;
        private ClusterCompressedDouble nextCompressedValue;
        private Double currentValue;
        private Integer iterableArraySize;

        global ClusterCompressedDoubleArrayIterator(ClusterCompressedDoubleArray value) {
            this.iterableArray = value;
            this.iterableArraySize = value.size();
            this.currentArrayIndex = -1;
            this.currentValueIndex = -1;
            this.currentCompressedValue = null;
            this.nextArrayIndex = -1;
            this.nextValueIndex = -1;
            this.nextCompressedValue = null;
        }

        global Boolean hasNext() {
            this.nextArrayIndex = this.currentArrayIndex;
            if (this.currentCompressedValue != null) {
                if (this.currentValueIndex + 1 < this.currentCompressedValue.count) {
                    this.nextValueIndex = this.currentValueIndex + 1;
                    this.nextCompressedValue = this.currentCompressedValue;
                    return true;
                }
                else {
                    this.nextValueIndex = -1;
                    this.nextCompressedValue = null;
                    this.nextArrayIndex++;
                }
            }
            else {
                this.nextArrayIndex++;
            }
            return this.nextArrayIndex < this.iterableArraySize;            
        }

        global Double next() {
            if (this.nextArrayIndex > -1) {
                this.currentArrayIndex = this.nextArrayIndex;
                this.currentValueIndex = this.nextValueIndex;
                this.currentCompressedValue = this.nextCompressedValue;
                this.nextArrayIndex = -1;
                Boolean result = this.currentArrayIndex < this.iterableArraySize;
                this.currentValue = result ? this.getValueInternal() : null;
            }
            else {
                this.moveNext();
            }
            return this.currentValue;
        }

        global Boolean moveNext() {
            if (this.currentCompressedValue != null) {
                if (this.currentValueIndex < this.currentCompressedValue.count - 1) {
                    this.currentValueIndex++;
                }
                else {
                    this.currentCompressedValue = null;
                    this.currentValueIndex = -1;
                    this.currentArrayIndex++;
                }
            }
            else {
                this.currentArrayIndex++;
            }
            Boolean result = this.currentArrayIndex < this.iterableArraySize;
            this.currentValue = result ? this.getValueInternal() : null;
            return result;
        }

        global Double getValue() {
            return this.currentValue;
        }

        private Double getValueInternal() {
            if (this.currentCompressedValue != null) {
                return this.currentCompressedValue.value;
            }
            this.currentCompressedValue = this.iterableArray.values[this.currentArrayIndex];
            this.currentValueIndex = 0;
            return this.currentCompressedValue.value;
        }
    }

    @AuraEnabled
    public List<ClusterCompressedDouble> values;
    private transient Double prevValue;

    global ClusterCompressedDoubleArray() {
        this.values = new List<ClusterCompressedDouble>();
        this.prevValue = null;
    }

    global ClusterCompressedDoubleArray(List<Double> doubleArray) {
        this();
        for (Double d:doubleArray) {
            this.add(d);
        }
    }

    global void add(Double value) {
        Integer size = this.values.size();
        if (size == 0 || this.prevValue == null) {
            this.values.add(new ClusterCompressedDouble(value));
            this.prevValue = value;
        }
        else {
            if (ClusterDataHelper.doublesEqual(this.prevValue, value)) {
                ClusterCompressedDouble prevItem = this.values.get(size - 1);
                prevItem.count++;
            }
            else {
                ClusterCompressedDouble ccd = new ClusterCompressedDouble(value);
                this.values.add(ccd);
                this.prevValue = ccd.value;
            }
        }
    }

    global void addCompressedValue(Double value, Integer count) {
        ClusterCompressedDouble cv = new ClusterCompressedDouble();
        cv.value = value;
        cv.count = count;
        this.values.add(cv);
        this.prevValue = value;
    }

    global void addCompressedValue(ClusterCompressedDouble value) {
        this.values.add(value);
        this.prevValue = value.value;
    }

    public Integer size() {
        return this.values.size();
    }

    public ClusterCompressedDouble get(Integer index) {
        return this.values.get(index);
    }

    global List<ClusterCompressedDouble> getCompressedList() {
        return this.values;
    }

    global List<Double> toList() {
        ClusterCompressedDoubleArrayIterator ci = this.iterator();
        List<Double> decompressed = new List<Double>();
        while (ci.moveNext()) {
            decompressed.add(ci.getValue());
        }
        return decompressed;
    }

    global ClusterCompressedDoubleArrayIterator iterator() {
        return new ClusterCompressedDoubleArrayIterator(this);
    }

    public static ClusterCompressedDoubleArray createFromJsonMap(Map<String, Object> arrayValues) {
        ClusterCompressedDoubleArray ccda = new ClusterCompressedDoubleArray();
        if (arrayValues != null) {
            Object[] compressedValues = (Object[])arrayValues.get('values');
            if (compressedValues != null) {
                for (Object arrayValue:compressedValues) {
                    Map<String,Object> ccdValues = (Map<String,Object>)arrayValue;
                    ClusterCompressedDoubleArray.ClusterCompressedDouble ccd = new ClusterCompressedDoubleArray.ClusterCompressedDouble();
                    ccd.count = (Integer)ccdValues.get('count');
                    ccd.value = Double.valueOf(ccdValues.get('value'));
                    ccda.addCompressedValue(ccd);
                }
            }
        }
        return ccda;
    }
}
