({
    clusterColors: ["#1b70fc", "#faff16", "#d50527", "#158940", "#f898fd", "#24c9d7", "#cb9b64", "#866888", "#22e67a",
        "#e509ae", "#9dabfa", "#437e8a", "#b21bff", "#ff7b91", "#94aa05", "#ac5906", "#82a68d", "#fe6616", "#7a7352", "#f9bc0f",
        "#b65d66", "#07a2e6", "#c091ae", "#8a91a7", "#88fc07", "#ea42fe", "#9e8010", "#10b437", "#c281fe", "#f92b75", "#07c99d",
        "#a946aa", "#bfd544", "#16977e", "#ff6ac8", "#a88178", "#5776a9", "#678007", "#fa9316", "#85c070", "#6aa2a9", "#989e5d",
        "#fe9169", "#cd714a", "#6ed014", "#c5639c", "#c23271", "#698ffc", "#678275", "#c5a121", "#a978ba", "#ee534e", "#d24506",
        "#59c3fa", "#ca7b0a", "#6f7385", "#9a634a", "#48aa6f", "#ad9ad0", "#d7908c", "#6a8a53", "#8c46fc", "#8f5ab8", "#fd1105",
        "#7ea7cf", "#d77cd1", "#a9804b", "#0688b4", "#6a9f3e", "#ee8fba", "#a67389", "#9e8cfe", "#bd443c", "#6d63ff", "#d110d5",
        "#798cc3", "#df5f83", "#b1b853", "#bb59d8", "#1d960c", "#867ba8", "#18acc9", "#25b3a7", "#f3db1d", "#938c6d", "#936a24",
        "#a964fb", "#92e460", "#a05787", "#9c87a0", "#20c773", "#8b696d", "#78762d", "#e154c6", "#40835f", "#d73656", "#1afd5c",
        "#c4f546", "#3d88d8", "#bd3896", "#1397a3", "#f940a5", "#66aeff", "#d097e7", "#fe6ef9", "#d86507", "#8b900a", "#d47270",
        "#e8ac48", "#cf7c97", "#cebb11", "#718a90", "#e78139", "#ff7463", "#bea1fd"],
    
    getClusterColor: function(clusterIndex) {
        return this.clusterColors[clusterIndex];
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
        let color = helper.getClusterColor(dataPoint.clusterIndex);
        component.set('v.clusterColorCss', 'background-color: ' + color);
        let clusterDivComponent = component.find("clusterBox");        
        if (clusterDivComponent) {
            $A.util.addClass(clusterDivComponent, 'crd_clusterbox');
        }
    }
})