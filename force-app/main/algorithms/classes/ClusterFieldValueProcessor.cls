/*
 * Interface for field value converters
 *
 * @author: Iskander Mukhamedgaliyev
 */
public interface ClusterFieldValueProcessor {
    Object processFieldValue(SObject record, ClusterModelFieldWrapper fieldDesc, ClusterMinMaxValue minMaxValue);
    void processTotals(ClusterModelFieldWrapper fieldDesc, ClusterMinMaxValue minMaxValue, Integer recordCount);
    Object parseValueFromJson(JSONParser parser);
    void serializeValueToJson(JSONGenerator gen, Object value);
}