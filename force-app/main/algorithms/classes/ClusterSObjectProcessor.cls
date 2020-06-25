/*
 * Convert and vectorize SObject into ClusterDataPoint
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterSObjectProcessor {
    private ClusterJobState jobState;
    private ClusterFieldValueProcessor scalarProcessor;
    private ClusterFieldValueProcessor longTextProcessor;

    public ClusterSObjectProcessor(ClusterJobState state) {
        this.jobState = state;
        this.scalarProcessor = new ClusterScalarFieldValueProcessor(this.jobState);
        this.longTextProcessor = new ClusterLongTextFieldValueProcessor(this.jobState);
    }

    public ClusterDataPoint processSObject(SObject record) {
        ClusterFieldValueProcessor fieldProcessor;
        ClusterDataPoint dp = new ClusterDataPoint();
        Integer fieldSize = this.jobState.model.fields.size();
        ClusterModelWrapper model = this.jobState.model;
        dp.values = new Object[fieldSize];
        for (Integer i = 0; i < fieldSize; i++) {
            fieldProcessor = model.fields[i].isLongText ? this.longTextProcessor : this.scalarProcessor;
            Object fieldValue = fieldProcessor.processFieldValue(record, model.fields[i], this.jobState.minMaxValues[i]);
            dp.values[i] = fieldValue;
            if (model.fields[i].isIdField) {
                dp.externalId = String.valueOf(fieldValue);
            }
            if (model.fields[i].isNameField) {
                dp.recordName = String.valueOf(fieldValue);
            }
        }
        if ((dp.recordName == null) || (dp.recordName == '')) {
            dp.recordName = dp.externalId;
        }
        return dp;
    }

    public void processTotals() {
        ClusterFieldValueProcessor fieldProcessor;
        Integer fieldSize = this.jobState.model.fields.size();
        for (Integer i = 0; i < fieldSize; i++) {
            fieldProcessor = this.jobState.model.fields[i].isLongText ? this.longTextProcessor : this.scalarProcessor;
            fieldProcessor.processTotals(this.jobState.model.fields[i], this.jobState.minMaxValues[i], this.jobState.numRecords);
        }
    }

    public Object[] parseValuesFromJson(string jsonValues) {
        //We have to use our own json parser (with blackjack :)) because standard parser converts Double[] to Object[] which takes 3 times more Apex heap
        JSONParser parser = JSON.createParser(jsonValues);
        JSONToken nextToken = parser.nextToken();
        Object[] values = null;
        if (nextToken == JSONToken.START_ARRAY) {
            values = new Object[this.jobState.model.fields.size()];
            for (Integer i = 0; i < this.jobState.model.fields.size(); i++) {
                ClusterModelFieldWrapper field = this.jobState.model.fields[i];
                Object value;
                if (field.isLongText) {
                    value = this.longTextProcessor.parseValueFromJson(parser);
                }
                else {
                    value = this.scalarProcessor.parseValueFromJson(parser);
                }
                values[i] = value;
            }
        }
        return values;
    }
}
