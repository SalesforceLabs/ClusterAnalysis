export default class clustanUtils {
    static decompressJobState(jobState) {
        let model = jobState.model;
        for (let i = 0; i < model.fields.length; i++) {
            if (model.fields[i].isLongText) {
                //Decompressing idf
                jobState.minMaxValues[i].maxValue = this.decompressRLEArray(jobState.minMaxValues[i].maxValue);
                //Decompressing centroids
                jobState.centroids.forEach(c => c.values[i] = this.decompressRLEArray(c.values[i]));
            }
        }        

    }

    static decompressDataPointValues(jobState, values) {
        let model = jobState.model;
        for (let i = 0; i < model.fields.length; i++) {
            if (model.fields[i].isLongText) {
                values[i] = this.decompressRLEArray(values[i]);
            }
        }        
    }

    static decompressRLEArray(rleArray) {
        let values = [];
        if (rleArray) {
            if (rleArray.rle && Array.isArray(rleArray.rle)) {
                rleArray = rleArray.rle;
            }
            else if (rleArray.values && Array.isArray(rleArray.values)) {
                rleArray = rleArray.values;
            }
            else if (!Array.isArray(rleArray)) {
                return values;
            }
            for (let i=0; i<rleArray.length; i++) {
                let rleValue = rleArray[i];
                if (rleValue && Array.isArray(rleValue)) {
                    let count = rleValue[0];
                    let value = rleValue[1];
                    for (let cIndex = 0; cIndex < count; cIndex++) {
                        values.push(value);
                    }
                }
                else if (rleValue.hasOwnProperty('count') && rleValue.hasOwnProperty('value')) {
                    let count = rleValue.count;
                    let value = rleValue.value;
                    for (let cIndex = 0; cIndex < count; cIndex++) {
                        values.push(value);
                    }
                }
                else {
                    values.push(rleValue);
                }
            }
        }
        return values;
    }

    // code from https://github.com/trekhleb/javascript-algorithms/tree/master/src/algorithms/string/levenshtein-distance
    static levenshteinDistance(a, b) {
        // Create empty edit distance matrix for all possible modifications of
        // substrings of a to substrings of b.
        const distanceMatrix = Array(b.length + 1).fill(null).map(() => Array(a.length + 1).fill(null));

        // Fill the first row of the matrix.
        // If this is first row then we're transforming empty string to a.
        // In this case the number of transformations equals to size of a substring.
        for (let i = 0; i <= a.length; i += 1) {
            distanceMatrix[0][i] = i;
        }

        // Fill the first column of the matrix.
        // If this is first column then we're transforming empty string to b.
        // In this case the number of transformations equals to size of b substring.
        for (let j = 0; j <= b.length; j += 1) {
            distanceMatrix[j][0] = j;
        }

        for (let j = 1; j <= b.length; j += 1) {
            for (let i = 1; i <= a.length; i += 1) {
                const indicator = a[i - 1] === b[j - 1] ? 0 : 1;
                distanceMatrix[j][i] = Math.min(
                    distanceMatrix[j][i - 1] + 1, // deletion
                    distanceMatrix[j - 1][i] + 1, // insertion
                    distanceMatrix[j - 1][i - 1] + indicator // substitution
                );
            }
        }

        return distanceMatrix[b.length][a.length];
    }
    
    static calculateNumericGowerDistance(a, b, delta) {
        if (a == null && b == null) return 0;
        let d = 0;
        try {
            d = Math.abs(a - b) / delta;
        }
        catch (ex) { 
            d = 1;
        }
        return isNaN(d) ? 1.0 : d;
    }

    static calculateTextGowerDistance(a, b, min, max) {
        if (a == null && b == null) return 0;
        let r = max;
        let d = 0;
        try {
            if (a == null) {
                d = Number(b.length()) / r;
            }
            else if (b == null) {
                d = Number(a.length()) / r;
            }
            else d = this.levenshteinDistance(a, b) / r;
        }
        catch (ex) { 
            d = 1;
        }
        return isNaN(d) ? 1.0 : d;
    }

    static calculateCategoryGowerDistance(a, b) {
        if (a == null && b == null) return 0;
        return (a == b) ? 0 : 1;
    }

    static gowerDistance(currentObject, centroid, jobState) {
        let distance = 0;
        let weight = 0;
        let model = jobState.model;
        for (let i = 0; i < model.fields.length; i++) {
            if (model.fields[i].isNumeric) {
                distance += model.fields[i].weight * this.calculateNumericGowerDistance(Number(currentObject[i]), Number(centroid[i]),
                    Number(jobState.minMaxValues[i].delta));
                weight += model.fields[i].weight;
            }
            else if (model.fields[i].isText) {
                distance += model.fields[i].weight * this.calculateTextGowerDistance(String(currentObject[i]), String(centroid[i]),
                    Number(jobState.minMaxValues[i].minValue), Number(jobState.minMaxValues[i].maxValue));
                weight += model.fields[i].weight;
            }
            else if (model.fields[i].isCategory) {
                distance += model.fields[i].weight * this.calculateCategoryGowerDistance(String(currentObject[i]), String(centroid[i]));
                weight += model.fields[i].weight;
            }
            else if (model.fields[i].isLongText) {
                let tf1 = currentObject[i];
                let tf2 = centroid[i];
                let idf = jobState.minMaxValues[i].maxValue;
                distance += model.fields[i].weight * this.calculateCosineDistance(tf1, tf2, idf);
                weight += model.fields[i].weight;
            }
        }
        return distance / weight;
    }

    static calculateSimilarity(currentObject, centroid, jobState) {
        let model = jobState.model;
        let similarityValues = [];
        for (let i = 0; i < model.fields.length; i++) {
            if (model.fields[i].isNumeric) {
                similarityValues.push(1.0 - this.calculateNumericGowerDistance(Number(currentObject[i]), Number(centroid[i]),
                    Number(jobState.minMaxValues[i].delta)));
            }
            else if (model.fields[i].isText) {
                similarityValues.push(1.0 - this.calculateTextGowerDistance(String(currentObject[i]), String(centroid[i]),
                    Number(jobState.minMaxValues[i].minValue), Number(jobState.minMaxValues[i].maxValue)));
            }
            else if (model.fields[i].isCategory) {
                similarityValues.push(1.0 - this.calculateCategoryGowerDistance(String(currentObject[i]), String(centroid[i])));
            }
            else if (model.fields[i].isLongText) {
                let tf1 = currentObject[i];
                let tf2 = centroid[i];
                let idf = jobState.minMaxValues[i].maxValue;
                similarityValues.push(1.0 - model.fields[i].weight * this.calculateCosineDistance(tf1, tf2, idf));
            }
            else {
                similarityValues.push(null); //Return null for non-data fields
            }
        }
        return similarityValues;
    }

    static calculateCosineDistance(vector1, vector2, idfVector) {
        if (vector1 == null && vector2 == null) return 0.0;
        if (vector1 == null || vector2 == null) return 1.0;
        // Cosine similarity returns 1 if vectors are equal, subtracting from 1 will convert it to the distance
        return 1.0 - this.calculateCosineSimilarity(vector1, vector2, idfVector);
    }

    static calculateCosineSimilarity(vector1, vector2, idfVector) {
        //We will also use idf vector in calculations to optimize loops a little
        let dotProduct = 0.0;
        let magnitude1 = 0.0;
        let magnitude2 = 0.0;
        let zero = 0.0;
        //Vector sizes might be different
        let v1Size = vector1.length;
        let v2Size = vector2.length;
        let idfSize = idfVector.length;
        let length = Math.max(v1Size, v2Size);
        for (let i = 0; i < length; i++) {
            let v1 = i < v1Size ? vector1[i] : zero;
            let v2 = i < v2Size ? vector2[i] : zero;
            if ((idfVector != null) && i < idfSize) {
                v1 = v1 * idfVector[i];
                v2 = v2 * idfVector[i];
            }
            dotProduct += v1 * v2;
            magnitude1 += v1 * v1;
            magnitude2 += v2 * v2;
        }
        magnitude1 = Math.sqrt(magnitude1);
        magnitude2 = Math.sqrt(magnitude2);
        let magnitude = magnitude1 * magnitude2;
        if (this.doublesEqual(magnitude, zero)) {
            return 1.0;
        }
        else {
            return dotProduct / magnitude;
        }
    }

    static convertDataPointValue(fieldIndex, fieldValue, jobState) {
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
    }

    static getTopKeywords(tf, idf, keywords, count) {
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
    }    

    static doublesEqual(a, b) {
        return Math.abs(a-b) < 0.000001;
    }
}
