/*
 * Calculates TF-IDF vectors
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterLongTextFieldValueProcessor implements ClusterFieldValueProcessor {
    public static final String WORD_SPLIT_REGEX = '\\s|\\n|\\r|\\?|\\!|\\.|\\,|\\*|\\||\\(|\\)|\\[|\\]|\\{|\\}|\\"|\\`|\\$|\\^|\\~|\\/|\\\\|\\;|\\:|\\=';
    public static final String JSON_RLE_NAME = 'rle';
    public static final Integer TFIDF_SCALE = 7;
    private static Logger log = LogFactory.getLogger();
    ClusterJobState jobState;
    Map<String,ClusterWordPreprocessor> wordPreprocessors;
    Boolean useCompression;

    public ClusterLongTextFieldValueProcessor(ClusterJobState state) {
        this.jobState = state;
        this.useCompression = false;
        List<UiSelectOption> languages = ClusterConstants.getSupportedModelLanguages();
        this.wordPreprocessors = new Map<String,ClusterWordPreprocessor>();
        for (UiSelectOption language : languages) {
            wordPreprocessors.put(language.value.toLowerCase(), new ClusterWordPreprocessor(language.value.toLowerCase()));
        }
    }

    public void setCompression(Boolean compression) {
        this.useCompression = compression;
    }

    public Object processFieldValue(SObject record, ClusterModelFieldWrapper fieldDesc, ClusterMinMaxValue minMaxValue) {
        //Initializing word counter map and word list if needed
        Map<String, Integer> wordMap;
        try {
            wordMap = (Map<String, Integer>)minMaxValue.maxValue;
            if (wordMap == null) {
                wordMap = new Map<String, Integer>();
                minMaxValue.maxValue =wordMap;
            }
        }
        catch (System.TypeException ex) {
            //TODO: This is an ugly workaround for "System.TypeException: Invalid conversion from runtime type clustan.ClusterCompressedDoubleArray to Map<String,Integer>"
            //in predict code flow
            wordMap = new Map<String, Integer>();
        }
        List<String> wordList = (List<String>)minMaxValue.minValue;
        if (wordList == null) {
            wordList = new List<String>();
            minMaxValue.minValue = wordList;
        }
        
        Object fieldValue = ClusterDataHelper.getSObjectFieldValue(record, fieldDesc);
        if (fieldValue == null) {
            return null;
        }
        String text = String.valueOf(fieldValue);
        if (text == '') {
            return null;
        }
        String language = fieldDesc.language != null ? fieldDesc.language.toLowerCase() : ClusterConstants.LANGUAGE_NONE;
        if (this.useCompression) {
            return calculateCompressedTF(text, wordMap, wordList, this.wordPreprocessors.get(language));
        }
        else {
            Double[] tf = calculateTF(text, wordMap, wordList, this.wordPreprocessors.get(language));
            return tf;
        }
    }

    private static String[] splitText(String text) {
        return text==null ? null : text.split(WORD_SPLIT_REGEX);
    }

    private static Integer prepareWordList(String text, Map<String, Integer> wordMap, List<String> wordList, Map<String, Integer> currentWordMap, ClusterWordPreprocessor wordPreprocessor) {
        if (text == '') {
            return null;
        }
        //Removing html tags and breaking into words
        String[] words = splitText(text.stripHtmlTags());

        Integer numTokens = 0;
        for (Integer i = 0; i < words.size(); i++) {
            //Skip empty and single character words
            if (words[i].length() < 2) {
                continue;
            }
            String token = wordPreprocessor != null ? wordPreprocessor.preprocess(words[i]) : words[i];
            //Skip words that were filtered out by the preprocessor
            if (token == null) {
                continue;
            }
            addWordToMap(token, currentWordMap, 1, null);
            numTokens++;
        }
        //Adding words and updating counts in aggregated structures
        for (String currentToken:currentWordMap.keySet()) {
            addWordToMap(currentToken, wordMap, 1, wordList); // Adding 1 here because for IDF we need to calculate the number of documents containing this term
        }
        return numTokens;
    }
    
    public static Double[] calculateTF(String text, Map<String, Integer> wordMap, List<String> wordList, ClusterWordPreprocessor wordPreprocessor) {
        //This will contain word counts for the current document
        Map<String, Integer> currentWordMap = new Map<String,Integer>();

        Integer numTokens = prepareWordList(text, wordMap, wordList, currentWordMap, wordPreprocessor);
        //Calculating tf for the text
        Double[] tf = new Double[wordList.size()];
        for (Integer i=0; i<wordList.size(); i++) {
            String currentToken = wordList.get(i);
            Integer wordCount = currentWordMap.get(currentToken);
            if (wordCount != null && numTokens > 0) {
                tf[i] = Double.valueOf(wordCount) / Double.valueOf(numTokens);
            }
            else {
                tf[i] = 0.0;
            }
        }
        return tf;
    }

    public static ClusterCompressedDoubleArray calculateCompressedTF(String text, Map<String, Integer> wordMap, List<String> wordList, ClusterWordPreprocessor wordPreprocessor) {
        //This will contain word counts for the current document
        Map<String, Integer> currentWordMap = new Map<String,Integer>();

        Integer numTokens = prepareWordList(text, wordMap, wordList, currentWordMap, wordPreprocessor);
        //Calculating tf for the text
        ClusterCompressedDoubleArray tf = new ClusterCompressedDoubleArray();
        for (Integer i=0; i<wordList.size(); i++) {
            String currentToken = wordList.get(i);
            Integer wordCount = currentWordMap.get(currentToken);
            if (wordCount != null && numTokens > 0) {
                tf.add(Double.valueOf(wordCount) / Double.valueOf(numTokens));
            }
            else {
                tf.add(ClusterDataHelper.DOUBLE_ZERO);
            }
        }
        return tf;
    }

    private static void addWordToMap(String word, Map<String, Integer> wordMap, Integer count, List<String> wordList) {
        Integer currentCount = wordMap.get(word);
        if (currentCount == null) {
            if ((wordList == null) || (wordList.size() < ClusterConstants.MAX_TFIDF_WORDBAG_SIZE)) {
                wordMap.put(word, count);
                //Also adding new word to the list
                if (wordList != null) {
                    wordList.add(word);
                }
            }
            else if (wordList != null) {
                log.debug('Maximum size of word bag reached. Cannot add new word "' + word + '" to the list');
            }
        }
        else {
            wordMap.put(word, currentCount + count);
        }
    }

    public void processTotals(ClusterModelFieldWrapper fieldDesc, ClusterMinMaxValue minMaxValue, Integer recordCount) {
        Map<String, Integer> wordMap = (Map<String, Integer>)minMaxValue.maxValue;
        List<String> wordList = (List<String>)minMaxValue.minValue;
        //We will replace global word count with IDF vector
        //TODO: although this will release some memory for futher processing it would be good to store the global word count somewhere
        if (this.useCompression) {
            minMaxValue.maxValue = calculateCompressedIDF(wordList, wordMap, recordCount);
        }
        else {
            minMaxValue.maxValue = calculateIDF(wordList, wordMap, recordCount);
        }
    }

    public static Double[] calculateIDF(List<String> wordList, Map<String, Integer> wordMap, Integer documentCount) {
        //Calculating idf for the set of documents
        Double[] idf = new Double[wordList.size()];
        for (Integer i=0; i<wordList.size(); i++) {
            String currentToken = wordList.get(i);
            Integer wordCount = wordMap.get(currentToken);
            if (wordCount != null && wordCount > 0) {
                //We will use base10 log for calculation
                idf[i] = Math.log10(Double.valueOf(documentCount) / Double.valueOf(wordCount));
            }
            else {
                idf[i] = 0.0;
            }
        }
        return idf;
    }

    public static ClusterCompressedDoubleArray calculateCompressedIDF(List<String> wordList, Map<String, Integer> wordMap, Integer documentCount) {
        //Calculating idf for the set of documents
        ClusterCompressedDoubleArray idf = new ClusterCompressedDoubleArray();
        for (Integer i=0; i<wordList.size(); i++) {
            String currentToken = wordList.get(i);
            Integer wordCount = wordMap.get(currentToken);
            if (wordCount != null && wordCount > 0) {
                //We will use base10 log for calculation
                idf.add(Math.log10(Double.valueOf(documentCount) / Double.valueOf(wordCount)));
            }
            else {
                idf.add(ClusterDataHelper.DOUBLE_ZERO);
            }
        }
        return idf;
    }

    public Object parseValueFromJson(JSONParser parser) {
        JSONToken nextToken = parser.nextToken();
        Object value;
        if (nextToken == JSONToken.VALUE_NULL) {
            value = null;
        }
        else if (nextToken == JSONToken.START_ARRAY) {
            nextToken = parser.nextToken();
            List<Double> tfList = new List<Double>();
            while (nextToken != JSONToken.END_ARRAY && nextToken != null) {
                if (nextToken == JSONToken.VALUE_NUMBER_FLOAT || nextToken == JSONToken.VALUE_NUMBER_INT || nextToken == JSONToken.VALUE_NULL) {
                    tfList.add(parser.getDoubleValue());
                }
                else {
                    throw new ClusterException('Cannot parse long text array item ' + parser.getText());
                }
                nextToken = parser.nextToken();
            }
            value = tfList;
        }
        else if (nextToken == JSONToken.START_OBJECT) {
            value = this.parseCompressedValueFromJson(parser);
        }
        else {
            throw new ClusterException('Cannot parse long text value ' + parser.getText());
        }
        return value;
    }

    private Object parseCompressedValueFromJson(JSONParser parser) {
        Object value;
        JSONToken nextToken = parser.nextValue();
        if (parser.getCurrentName() == JSON_RLE_NAME) {
            if (nextToken == JSONToken.START_ARRAY) {
                nextToken = parser.nextValue();
                ClusterCompressedDoubleArray ctfList = new ClusterCompressedDoubleArray();
                while (nextToken != JSONToken.END_ARRAY && nextToken != null) {
                    if (nextToken == JSONToken.VALUE_NUMBER_FLOAT || nextToken == JSONToken.VALUE_NUMBER_INT || nextToken == JSONToken.VALUE_NULL) {
                        ctfList.add(parser.getDoubleValue());
                    }
                    else if (nextToken == JSONToken.START_ARRAY) {                        
                        ClusterCompressedDoubleArray.ClusterCompressedDouble ccd = new ClusterCompressedDoubleArray.ClusterCompressedDouble();
                        nextToken = parser.nextToken();
                        ccd.count = parser.getIntegerValue();
                        nextToken = parser.nextToken();
                        ccd.value = parser.getDoubleValue();
                        ctfList.addCompressedValue(ccd);
                        nextToken = parser.nextToken();
                        if (nextToken != JSONToken.END_ARRAY) {
                            throw new ClusterException('Cannot parse compressed value ' + parser.getText());
                        }
                    }
                    else {
                        throw new ClusterException('Cannot parse compressed long text array item ' + parser.getText());
                    }
                    nextToken = parser.nextToken();
                }
                value = ctfList;
            }
            else if (nextToken == JSONToken.VALUE_NULL) {
                value = null;
            }
            else {
                throw new ClusterException('Cannot parse compressed long text value ' + parser.getText());    
            }
        }
        else {
            throw new ClusterException('Cannot parse compressed long text field name, expected: ' + JSON_RLE_NAME +' got: ' + parser.getCurrentName());    
        }
        nextToken = parser.nextToken();
        if (nextToken != JSONToken.END_OBJECT) {
            throw new ClusterException('Cannot parse compressed json object, expected: }, got: ' + parser.getText());
        }
        return value;
    }

    public void serializeValueToJson(JSONGenerator gen, Object value) {
        if (this.useCompression) {
            gen.writeStartObject();
            if (value != null) {
                gen.writeFieldName(JSON_RLE_NAME);
                gen.writeStartArray();
                ClusterCompressedDoubleArray ctfList = (ClusterCompressedDoubleArray)value;
                List<ClusterCompressedDoubleArray.ClusterCompressedDouble> compressedList = ctfList.getCompressedList();
                for (Integer i=0; i<compressedList.size(); i++) {
                    if (compressedList[i].count == 1) {
                        this.serializeDouble(gen, compressedList[i].value);
                    }
                    else {
                        ClusterCompressedDoubleArray.ClusterCompressedDouble ccd = (ClusterCompressedDoubleArray.ClusterCompressedDouble)compressedList[i];
                        gen.writeStartArray();
                        gen.writeNumber(ccd.count);
                        this.serializeDouble(gen, ccd.value);
                        gen.writeEndArray();
                    }
                }
                gen.writeEndArray();
            }
            else {
                gen.writeNullField(JSON_RLE_NAME);
            }
            gen.writeEndObject();
        }
        else {
            gen.writeStartArray();
            if (value != null) {
                Double[] values = (Double[])value;
                for (Integer i=0; i<values.size(); i++) {
                    this.serializeDouble(gen, values[i]);
                }
            }
            gen.writeEndArray();
        }
    }

    private void serializeDouble(JSONGenerator gen, Double value) {
        if (value == null) {
            gen.writeNull();
        }
        else if (ClusterDataHelper.doublesEqual(value, ClusterDataHelper.DOUBLE_ZERO)) {
            gen.writeNumber(ClusterDataHelper.INT_ZERO);
        }
        else {
            Decimal d = Decimal.valueOf(value);
            if (d.scale() > TFIDF_SCALE) {
                d = d.setScale(TFIDF_SCALE);
            }
            gen.writeNumber(d);
        }
    }
}