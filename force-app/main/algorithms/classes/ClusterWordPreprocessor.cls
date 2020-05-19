/*
 * Word preprocessor - removes stop words and performs stemming
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterWordPreprocessor {
    private Set<String> stopWords;

    public ClusterWordPreprocessor(Set<String> stopWords) {
        this.stopWords = stopWords;
    }

    public String preprocess(String word) {
        String processedWord = word.toLowerCase();
        if (this.stopWords.contains(processedWord)) {
            return null;
        }
        //TODO: implement stemmer
        return processedWord;
    }
    
}
