public class ClusterMinMaxValue {
    public ClusterMinMaxValue() {

    }

    public void loadFromMap(Map<String, Object> minMaxValues) {
        this.minValue = convertValue(minMaxValues.get('minValue'));
        this.maxValue = convertValue(minMaxValues.get('maxValue'));
        this.delta = Double.valueOf(convertValue(minMaxValues.get('delta')));
    }

    private Object convertValue(Object mapValue) {
        if ((mapValue instanceof String) || (mapValue instanceof Integer) || (mapValue instanceof Long) ||
            (mapValue instanceof Double) || (mapValue instanceof Decimal)) {
            return mapValue;
        }
        else if (mapValue instanceof Object[]) {
            return loadStringList(mapValue);
        }
        else if (mapValue instanceof Map<String, Object>) {
            return loadCompressedDoubleArray(mapValue);
        }
        return null;
    }

    private List<String> loadStringList(Object values) {
        List<String> sl = new List<String>();
        Object[] ol = (Object[])values;
        for (Object o:ol) {
            sl.add((String)o);
        }
        return sl;
    }

    private ClusterCompressedDoubleArray loadCompressedDoubleArray(Object values) {
        Map<String, Object> arrayValues = (Map<String, Object>)values;
        return ClusterCompressedDoubleArray.createFromJsonMap(arrayValues);
    }

    public object minValue;
    public object maxValue;
    public Double delta;
}