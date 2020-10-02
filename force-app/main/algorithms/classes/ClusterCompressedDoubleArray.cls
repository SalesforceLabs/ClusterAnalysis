/*
 * Compressed array of doubles to store TF-IDF arrays. Uses Run Length Encoding compression algorithm
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterCompressedDoubleArray {
    public class ClusterCompressedDouble {
        public Integer count;
        public Double value;
    }

    public class ClusterCompressedDoubleArrayIterator implements Iterator<Double> {
        private ClusterCompressedDoubleArray iterableArray;
        private Integer currentArrayIndex;
        private Integer currentValueIndex;
        private ClusterCompressedDouble currentCompressedValue;
        private Integer nextArrayIndex;
        private Integer nextValueIndex;
        private ClusterCompressedDouble nextCompressedValue;
        private Double currentValue;
        private Integer iterableArraySize;

        public ClusterCompressedDoubleArrayIterator(ClusterCompressedDoubleArray value) {
            this.iterableArray = value;
            this.iterableArraySize = value.size();
            this.currentArrayIndex = -1;
            this.currentValueIndex = -1;
            this.currentCompressedValue = null;
            this.nextArrayIndex = -1;
            this.nextValueIndex = -1;
            this.nextCompressedValue = null;
        }

        public Boolean hasNext() {
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

        public Double next() {
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

        public Boolean moveNext() {
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

        public Double getValue() {
            return this.currentValue;
        }

        private Double getValueInternal() {
            if (this.currentCompressedValue != null) {
                return this.currentCompressedValue.value;
            }
            //Object value = this.iterableArray.get(this.currentArrayIndex);
            Object value = this.iterableArray.values[this.currentArrayIndex];
            if (value instanceof ClusterCompressedDouble) {
                this.currentCompressedValue = (ClusterCompressedDouble)value;
                this.currentValueIndex = 0;
                return this.currentCompressedValue.value;
            }
            else {
                return (Double)value;
            }
        }
    }

    @TestVisible
    private List<Object> values;
    private transient Double prevValue;

    public ClusterCompressedDoubleArray() {
        this.values = new List<Object>();
        this.prevValue = null;
    }

    public void add(Double value) {
        Integer size = this.values.size();
        if (size == 0 || this.prevValue == null) {
            this.values.add(value);
            this.prevValue = value;
        }
        else {
            if (ClusterDataHelper.doublesEqual(this.prevValue, value)) {
                Object prevItem = this.values.get(size - 1);
                if (prevItem instanceOf ClusterCompressedDouble) {
                    ((ClusterCompressedDouble)prevItem).count++;
                }
                else {
                    ClusterCompressedDouble ccd = new ClusterCompressedDouble();
                    ccd.value = value;
                    ccd.count = 2;
                    this.values.set(size - 1, ccd);
                }
            }
            else {
                this.values.add(value);
                this.prevValue = value;    
            }
        }
    }

    public void addCompressedValue(Double value, Integer count) {
        ClusterCompressedDouble cv = new ClusterCompressedDouble();
        cv.value = value;
        cv.count = count;
        this.values.add(cv);
    }

    public void addCompressedValue(ClusterCompressedDouble value) {
        this.values.add(value);
    }


    public Integer size() {
        return this.values.size();
    }

    public Object get(Integer index) {
        return this.values.get(index);
    }

    public List<Object> getCompressedList() {
        return this.values;
    }

    public List<Double> toList() {
        ClusterCompressedDoubleArrayIterator ci = new ClusterCompressedDoubleArrayIterator(this);
        List<Double> decompressed = new List<Double>();
        while (ci.moveNext()) {
            decompressed.add(ci.getValue());
        }
        return decompressed;
    }

    public ClusterCompressedDoubleArrayIterator iterator() {
        return new ClusterCompressedDoubleArrayIterator(this);
    }
}
