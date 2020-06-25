/**
 * Converted to Apex from java code: https://github.com/apache/opennlp/blob/master/opennlp-tools/src/main/java/opennlp/tools/stemmer/PorterStemmer.java

 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 *
 * Stemmer, implementing the Porter Stemming Algorithm
 *
 * The Stemmer class transforms a word into its root form.  The input
 * word can be provided a character at time (by calling add()), or at once
 * by calling one of the various stem(something) methods.
 */
// CHECKSTYLE:OFF
public with sharing class ClusterPorterStemmer implements ClusterStemmer {
    private String[] b; //TODO: here and below the code uses String[] as a replacement for char[]. Ideally this could be just String
    private Integer i,    /* offset into b */
      j, k, k0;
    private Boolean dirty = false;
    private static final Integer INC = 50;
  
    public ClusterPorterStemmer() {      
      b = new List<String>();
      i = 0;
    }
  
    /**
     * reset() resets the stemmer so it can stem another word.  If you invoke
     * the stemmer by calling add(char) and then stem(), you must call reset()
     * before starting another word.
     */
    public void reset() { i = 0; dirty = false; }
  
    /**
     * Add a character to the word being stemmed.  When you are finished
     * adding characters, you can call stem(void) to process the word.
     */
    public void add(String ch) {      
        b.add(ch);
        this.i++;
    }
  
    /**
     * After a word has been stemmed, it can be retrieved by toString(),
     * or a reference to the internal buffer can be retrieved by getResultBuffer
     * and getResultLength (which is generally more efficient.)
     */
    public override String toString() { 
        String result = '';
        for (Integer index = 0; index < this.i; index++) {
          result += this.b[index];
        }
        return result;
    }
  
    /**
     * Returns the length of the word resulting from the stemming process.
     */
    public Integer getResultLength() { return i; }
  
    /**
     * Returns a reference to a character buffer containing the results of
     * the stemming process.  You also need to consult getResultLength()
     * to determine the length of the result.
     */
    public String[] getResultBuffer() { return b; }
  
    /* cons(i) is true <=> b[i] is a consonant. */
  
    private Boolean cons(Integer ii) {
      switch on b[ii] {
        when 'a', 'e', 'i', 'o', 'u' {
            return false;
        }
        when 'y' {
            return (ii == k0) || !cons(ii - 1);
        }
        when else {
            return true;
        }
      }
    }
  
    /* m() measures the number of consonant sequences between k0 and j. if c is
       a consonant sequence and v a vowel sequence, and <..> indicates arbitrary
       presence,
            <c><v>       gives 0
            <c>vc<v>     gives 1
            <c>vcvc<v>   gives 2
            <c>vcvcvc<v> gives 3
            ....
    */
  
    private Integer m() {
        Integer n = 0;
        Integer ii = k0;
      while(true) {
        if (ii > j)
          return n;
        if (! cons(ii))
          break;
        ii++;
      }
      ii++;
      while(true) {
        while(true) {
          if (ii > j)
            return n;
          if (cons(ii))
            break;
          ii++;
        }
        ii++;
        n++;
        while(true) {
          if (ii > j)
            return n;
          if (! cons(ii))
            break;
          ii++;
        }
        ii++;
      }
      return n; //Added to fix missing return error
    }
  
    /* vowelinstem() is true <=> k0,...j contains a vowel */
  
    private Boolean vowelinstem() {
      Integer ii;
      for (ii = k0; ii <= j; ii++)
        if (! cons(ii))
          return true;
      return false;
    }
  
    /* doublec(j) is true <=> j,(j-1) contain a double consonant. */
  
    private Boolean doublec(Integer jj) {
      return (jj >= k0 + 1) && (b[jj] == b[jj - 1]) && cons(jj);
    }
  
    /* cvc(i) is true <=> i-2,i-1,i has the form consonant - vowel - consonant
       and also if the second c is not w,x or y. this is used when trying to
       restore an e at the end of a short word. e.g.
            cav(e), lov(e), hop(e), crim(e), but
            snow, box, tray.
    */
  
    private Boolean cvc(Integer ii) {
      if (ii < k0+2 || !cons(ii) || cons(ii-1) || !cons(ii-2))
        return false;
      else {
        String ch = b[ii];
        if (ch == 'w' || ch == 'x' || ch == 'y') return false;
      }
      return true;
    }
  
    private boolean ends(String s) {
        Integer l = s.length();
        Integer o = k-l+1;
      if (o < k0)
        return false;
      for (Integer ii = 0; ii < l; ii++) //there is a private var i already
        if (b[o+ii] != s.subString(ii, ii+1)) {
          return false;
        }
      j = k-l;
      return true;
    }
  
    /* setto(s) sets (j+1),...k to the characters in the string s, readjusting
       k. */
  
    void setto(String s) {
        Integer l = s.length();
        Integer o = j+1;
      for (Integer ii = 0; ii < l; ii++)
        b[o+ii] = s.subString(ii, ii+1);
      k = j+l;
      dirty = true;
    }
  
    /* r(s) is used further down. */
  
    void r(String s) { if (m() > 0) setto(s); }
  
    /* step1() gets rid of plurals and -ed or -ing. e.g.
             caresses  ->  caress
             ponies    ->  poni
             ties      ->  ti
             caress    ->  caress
             cats      ->  cat
             feed      ->  feed
             agreed    ->  agree
             disabled  ->  disable
             matting   ->  mat
             mating    ->  mate
             meeting   ->  meet
             milling   ->  mill
             messing   ->  mess
             meetings  ->  meet
    */
  
    private void step1() {
      if (b[k] == 's') {
        if (ends('sses')) k -= 2;
        else if (ends('ies')) setto('i');
        else if (b[k-1] != 's') k--;
      }
      if (ends('eed')) {
        if (m() > 0)
          k--;
      }
      else if ((ends('ed') || ends('ing')) && vowelinstem()) {
        k = j;
        if (ends('at')) setto('ate');
        else if (ends('bl')) setto('ble');
        else if (ends('iz')) setto('ize');
        else if (doublec(k)) {
          String ch = b[k--];
          if (ch == 'l' || ch == 's' || ch == 'z')
            k++;
        }
        else if (m() == 1 && cvc(k))
          setto('e');
      }
    }
  
    /* step2() turns terminal y to i when there is another vowel in the stem. */
  
    private void step2() {
      if (ends('y') && vowelinstem()) {
        b[k] = 'i';
        dirty = true;
      }
    }
  
    /* step3() maps double suffices to single ones. so -ization ( = -ize plus
       -ation) maps to -ize etc. note that the string before the suffix must give
       m() > 0. */
  
    private void step3() {
      if (k == k0) return; /* For Bug 1 */
      switch on b[k-1] {
      when 'a' {
        if (ends('ational')) { r('ate'); }
        else if (ends('tional')) { r('tion'); }
      }
      when 'c' {
        if (ends('enci')) { r('ence'); }
        else if (ends('anci')) { r('ance'); }
      }
      when 'e' {
        if (ends('izer')) { r('ize'); }
      }
      when 'l' {
        if (ends('bli')) { r('ble'); }
        else if (ends('alli')) { r('al'); }
        else if (ends('entli')) { r('ent'); }
        else if (ends('eli')) { r('e'); }
        else if (ends('ousli')) { r('ous'); }
      }
      when 'o' {
        if (ends('ization')) { r('ize'); }
        else if (ends('ation')) { r('ate'); }
        else if (ends('ator')) { r('ate'); }
      }
      when 's' {
        if (ends('alism')) { r('al'); }
        else if (ends('iveness')) { r('ive'); }
        else if (ends('fulness')) { r('ful'); }
        else if (ends('ousness')) { r('ous'); }
      }
      when 't' {
        if (ends('aliti')) { r('al'); }
        else if (ends('iviti')) { r('ive'); }
        else if (ends('biliti')) { r('ble'); }
      }
      when 'g' {
        if (ends('logi')) { r('log'); }
      }
      }
    }
  
    /* step4() deals with -ic-, -full, -ness etc. similar strategy to step3. */
  
    private void step4() {
      switch on b[k] {
      when 'e' {
        if (ends('icate')) { 
            r('ic');
        }
        else if (ends('ative')) { 
            r(''); 
        }
        else if (ends('alize')) 
        { 
            r('al'); 
        }
      }
      when 'i' {
        if (ends('iciti')) { r('ic'); }
      }
      when 'l' {
        if (ends('ical')) { 
            r('ic'); 
        }
        else if (ends('ful')) { 
            r(''); 
        }
      }
      when 's' {
        if (ends('ness')) { r(''); }
      }
      }
    }
  
    /* step5() takes off -ant, -ence etc., in context <c>vcvc<v>. */
  
    private void step5() {
      if (k == k0) return; /* for Bug 1 */
      switch on b[k-1] {
      when 'a' {
        if (!ends('al')) return;
      }
      when 'c' {
        /*
        if (ends('ance')) break;
        if (ends('ence')) break;
        return;
        */
        if (!(ends('ance') || ends('ence'))) {
            return;
        }
      }
      when 'e' {
        if (!ends('er')) return;
      }
      when 'i' {
        if (!ends('ic')) return;
      }
      when 'l' {
        //if (ends("able")) break;
        //if (ends("ible")) break; return;
        if (!(ends('able') || ends('ible'))) {
            return;
        }
      }
      when 'n' {
        //if (ends("ant")) break;
        //if (ends("ement")) break;
        //if (ends("ment")) break;
        /* element etc. not stripped before the m */
        //if (ends("ent")) break;
        //return;
        if (!(ends('ant') || ends('ement') || ends('ment') || ends('ent'))) {
            return;
        }
      }
      when 'o' {
        //if (ends("ion") && j >= 0 && (b[j] == 's' || b[j] == 't')) break;
        /* j >= 0 fixes Bug 2 */
        //if (ends("ou")) break;
        //return;
        /* takes care of -ous */
        if  (!(
            (ends('ion') && j >= 0 && (b[j] == 's' || b[j] == 't')) ||
            (ends('ou'))
            )) {
            return;
        }
        /* j >= 0 fixes Bug 2 */
      }
      when 's' {
        if (!ends('ism')) return;
      }
      when 't' {
        //if (ends("ate")) break;
        //if (ends("iti")) break;
        //return;
        if (!(ends('ate') || ends('iti'))) {
            return;
        }
      }
      when 'u' {
        if (!ends('ous')) return;
      }
      when 'v' {
        if (!ends('ive')) return;
      }
      when 'z' {
        if (!ends('ize')) return;
      }
      when else {
        return;
      }
      }
      if (m() > 1)
        k = j;
    }
  
    /* step6() removes a final -e if m() > 1. */  
    
    private void step6() {
      j = k;
      if (b[k] == 'e') {
        Integer a = m();
        if (a > 1 || a == 1 && !cvc(k-1))
          k--;
      }
      if (b[k] == 'l' && doublec(k) && m() > 1)
        k--;
    }
  
  
    /**
     * Stem a word provided as a String.  Returns the result as a String.
     */
    public String stem(String s) {
        String[] charArray = new String[s.length()];
        for (Integer charIndex = 0; charIndex < charArray.size(); charIndex++) {
            charArray[charIndex] = s.subString(charIndex, charIndex + 1);
        }
      if (stem(charArray, s.length()))
        return toString();
      else
        return s;
    }
  
    /** Stem a word contained in a char[].  Returns true if the stemming process
     * resulted in a word different from the input.  You can retrieve the
     * result with getResultLength()/getResultBuffer() or toString().
     */
    public boolean stem(String[] word) {
      return stem(word, word.size());
    }
  
    /** Stem a word contained in a portion of a char[] array.  Returns
     * true if the stemming process resulted in a word different from
     * the input.  You can retrieve the result with
     * getResultLength()/getResultBuffer() or toString().
     */
    public boolean stem(String[] wordBuffer, Integer offset, Integer wordLen) {
      this.b = wordBuffer;
      i = wordLen;
      return stem(0);
    }
  
    /** Stem a word contained in a leading portion of a char[] array.
     * Returns true if the stemming process resulted in a word different
     * from the input.  You can retrieve the result with
     * getResultLength()/getResultBuffer() or toString().
     */
    public boolean stem(String[] word, Integer wordLen) {
      return stem(word, 0, wordLen);
    }
  
    /** Stem the word placed into the Stemmer buffer through calls to add().
     * Returns true if the stemming process resulted in a word different
     * from the input.  You can retrieve the result with
     * getResultLength()/getResultBuffer() or toString().
     */
    public boolean stem() {
      return stem(0);
    }
  
    public boolean stem(Integer i0) {
      k = i - 1;
      k0 = i0;
      if (k > k0+1) {
        step1(); step2(); step3(); step4(); step5(); step6();
      }
      // Also, a word is considered dirty if we lopped off letters
      // Thanks to Ifigenia Vairelles for pointing this out.
      if (i != k+1)
        dirty = true;
      i = k+1;
      return dirty;
    }
  }