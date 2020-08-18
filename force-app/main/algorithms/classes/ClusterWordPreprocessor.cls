/*
 * Word preprocessor - removes stop words and performs stemming
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterWordPreprocessor {
    private Set<String> stopWords;
    private ClusterStemmer stemmer;

    public ClusterWordPreprocessor(String language) {
        this.stopWords = ClusterConstants.getStopWords(language);
        this.stemmer = getStemmer(language);
    }

    public String preprocess(String word) {
        String processedWord = word.toLowerCase();
        if (this.stopWords.contains(processedWord)) {
            return null;
        }
        if (this.stemmer != null) {
            processedWord = this.stemmer.stem(processedWord);
        }
        return processedWord;
    }

    public static ClusterStemmer getStemmer(String language) {
        //TODO: implement factory when more stemmers will be implemented
        if (language.toLowerCase() == 'english') {
            return new ClusterPorterStemmer();
        }
        else {
            return null;
        }
    }
    
}