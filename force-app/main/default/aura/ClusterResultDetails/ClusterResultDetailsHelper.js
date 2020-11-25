({
    getClusterColor: function(component) {
        return component.get('v.clusterColor');
    },

    convertDataPointValue : function(fieldIndex, fieldValue, jobState) {
        let result = '';
        let fieldDesc = jobState.model.fields[fieldIndex];
        if (fieldDesc.isLongText) {
            let idf = jobState.minMaxValues[fieldIndex].maxValue;
            let keywords = jobState.minMaxValues[fieldIndex].minValue;
            let tf = fieldValue;
            if (tf != null && tf.length > 0 && idf != null && idf.length > 0) {
                let keywordsNum = Math.min(20, keywords.length);
                result = this.getTopKeywords(tf, idf, keywords, keywordsNum);
                if (result) {
                    result = 'Top ' + keywordsNum.toString() + ' stemmed keywords: ' + result;
                }
            }
            else {
                result = '';
            }
        }
        else if (fieldDesc.dataType == 'datetime' && fieldValue != null) {
            result = new Date(fieldValue);
        }
        else {
            result = fieldValue;
        }
        return result;
    },

    getTopKeywords : function(tf, idf, keywords, count) {
        if (count == 0) return '';
        let sortedValues = new Array(idf.length);
        for (let ki = 0; ki < count; ki++) {
            let max = ki < tf.length ? tf[ki] * idf[ki] : 0.0;
            for (let i = ki; i < idf.length; i++) {
                let tfidf = i < tf.length ? tf[i] * idf[i] : 0.0;
                if (ki == 0) {
                    sortedValues[i] = { tfidf: tfidf, index: i };
                }
                if (sortedValues[i].tfidf > max) {
                    let currentMax = sortedValues[ki];
                    max = sortedValues[i].tfidf;
                    sortedValues[ki] = sortedValues[i];
                    sortedValues[i] = currentMax;                    
                }
            }
        }
        let sortedKeywords = '';
        for (let i=0; i < count; i++) {
            sortedKeywords += keywords[sortedValues[i].index];
            if (i < count - 1) {
                sortedKeywords += ', ';
            }
        }
        return sortedKeywords;
    },

    rebind: function(component, event, helper) {
        let dataPoint = component.get("v.dataPoint");
        let jobState = component.get("v.jobState");
        if (dataPoint == null || jobState == null) {
            return;
        }
        let model = jobState.model;
        let dpValues = dataPoint.values;
        let objectValues = dpValues.map((cv,index) => { return { 
            name: model.fields[index].name, value: helper.convertDataPointValue(index, cv, jobState)
        } });
        component.set('v.objectValues', objectValues);
        let color = helper.getClusterColor(component);
        component.set('v.clusterColorCss', 'background-color: ' + color);
        let clusterDivComponent = component.find("clusterBox");        
        if (clusterDivComponent) {
            $A.util.addClass(clusterDivComponent, 'crd_clusterbox');
        }
    }
})