/*
 * Calculates TF-IDF vectors
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterLongTextFieldValueProcessor implements ClusterFieldValueProcessor {
    public static final String WORD_SPLIT_REGEX = '\\s|\\n|\\r|\\?|\\!|\\.|\\,|\\*|\\||\\(|\\)|\\[|\\]|\\{|\\}|\\"|\\`|\\$|\\^|\\~|\\/|\\\\|\\;|\\:|\\=';
    public static final Integer TFIDF_SCALE = 5;
    private static Logger log = LogFactory.getLogger();
    ClusterJobState jobState;
    Map<String,ClusterWordPreprocessor> wordPreprocessors;

    public ClusterLongTextFieldValueProcessor(ClusterJobState state) {
        this.jobState = state;
        List<UiSelectOption> languages = ClusterConstants.getSupportedModelLanguages();
        this.wordPreprocessors = new Map<String,ClusterWordPreprocessor>();
        for (UiSelectOption language : languages) {
            wordPreprocessors.put(language.value.toLowerCase(), new ClusterWordPreprocessor(language.value.toLowerCase()));
        }
    }

    public Object processFieldValue(SObject record, ClusterModelFieldWrapper fieldDesc, ClusterMinMaxValue minMaxValue) {
        //Initializing word counter map and word list if needed
        Map<String, Integer> wordMap = (Map<String, Integer>)minMaxValue.maxValue;
        if (wordMap == null) {
            wordMap = new Map<String, Integer>();
            minMaxValue.maxValue =wordMap;
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
        Double[] tf = calculateTF(text, wordMap, wordList, this.wordPreprocessors.get(language));

        //Converting to decimal and reducing scale to save on memory and storage size
        //This array will be deserialized to json string and stored in results object
        //TODO: ideally there should be a json serializer which could support double formatting
        Decimal[] dtf = new Decimal[tf.size()];
        for (Integer i = 0; i < tf.size(); i++) {
            Decimal d = Decimal.valueOf(tf[i]);
            if (d.scale() > TFIDF_SCALE) {
                d.setScale(TFIDF_SCALE);
            }
            dtf[i] = d;
        }
        return dtf;
    }

    private static String[] splitText(String text) {
        return text==null ? null : text.split(WORD_SPLIT_REGEX);
    }

    public static Double[] calculateTF(String text, Map<String, Integer> wordMap, List<String> wordList, ClusterWordPreprocessor wordPreprocessor) {
        if (text == '') {
            return null;
        }
        //Removing html tags and breaking into words
        String[] words = splitText(text.stripHtmlTags());

        //This will contain word counts for the current document
        Map<String, Integer> currentWordMap = new Map<String,Integer>();
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
            addWordToMap(currentToken, wordMap, currentWordMap.get(currentToken), wordList);
        }
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
        minMaxValue.maxValue = calculateIDF(wordList, wordMap, recordCount);
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

    public Object parseValueFromJson(JSONParser parser) {
        JSONToken nextToken = parser.nextToken();
        Object value;
        if (nextToken == JSONToken.VALUE_NULL) {
            value = null;
        }
        else if (nextToken == JSONToken.START_ARRAY) {
            //Double[] tfList = (Double[])parser.readValueAs(Double[].class);
            //value = tfList;
            
            List<Double> tfList = new List<Double>();
            nextToken = parser.nextToken();
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
        else {
            throw new ClusterException('Cannot parse long text value ' + parser.getText());
        }
        return value;
    }
}
