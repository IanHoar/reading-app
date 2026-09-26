import Content
import Testing

@testable import SpeechRecognition

struct WordMatcherTests {
  let sat = Word(text: "sat")
  let knight = Word(text: "knight", homophones: ["night"])
  let mat = Word(text: "mat")

  @Test func exactMatch() {
    let match = WordMatcher.match(tokens: ["the", "cat", "sat"], current: sat, next: mat)
    #expect(match?.target == .current)
  }

  @Test func onlyTheLastThreeTokensCount() {
    #expect(WordMatcher.match(tokens: ["sat", "a", "b", "c"], current: sat, next: mat) == nil)
  }

  @Test func levenshteinOneIsAcceptedForLongerWords() {
    #expect(WordMatcher.match(tokens: ["knigh"], current: knight, next: nil)?.target == .current)
  }

  @Test func levenshteinIsNotAppliedToShortWords() {
    #expect(
      WordMatcher.match(tokens: ["sad"], current: sat, next: nil, strictness: .standard) == nil
    )
  }

  @Test func droppedFinalConsonantIsForgivenWhenGentle() {
    #expect(WordMatcher.match(tokens: ["sap"], current: sat, next: nil)?.target == .current)
    #expect(
      WordMatcher.match(tokens: ["sap"], current: sat, next: nil, strictness: .standard) == nil
    )
  }

  @Test func aDoubledFinalLetterIsForgivenWhenGentle() {
    #expect(WordMatcher.match(tokens: ["bob", "sapp"], current: sat, next: nil)?.target == .current)
  }

  @Test(arguments: ["oh", "awn"])
  func onIsHeardWithoutItsN(token: String) {
    let on = Word(text: "on")
    #expect(WordMatcher.match(tokens: [token], current: on, next: nil)?.target == .current)
    #expect(
      WordMatcher.match(tokens: [token], current: on, next: nil, strictness: .standard) == nil
    )
  }

  @Test(arguments: ["yep", "yup", "yipp"])
  func aShortWordStartingWithYIsHeardThroughItsVowel(token: String) {
    let yip = Word(text: "Yip")
    #expect(WordMatcher.match(tokens: [token], current: yip, next: nil)?.target == .current)
  }

  @Test func aSaidAsUhIsHeardEvenWhenTheRecogniserWritesOh() {
    let word = Word(text: "a")
    #expect(WordMatcher.match(tokens: ["oh"], current: word, next: nil)?.target == .current)
  }

  @Test(arguments: ["set", "sit", "said", "sed"])
  func aShortWordWithAnotherVowelIsHeardWhenGentle(token: String) {
    #expect(WordMatcher.match(tokens: [token], current: sat, next: nil)?.target == .current)
  }

  @Test(arguments: ["had", "head", "hed"])
  func hidIsHeardThroughItsCommonMishearings(token: String) {
    let hid = Word(text: "hid")
    #expect(WordMatcher.match(tokens: [token], current: hid, next: nil)?.target == .current)
  }

  @Test(arguments: ["cat", "hat", "sun", "seats"])
  func aShortWordStillNeedsItsOwnConsonants(token: String) {
    #expect(WordMatcher.match(tokens: [token], current: sat, next: nil) == nil)
  }

  @Test func theShortWordRuleStaysOffWhenStandard() {
    #expect(
      WordMatcher.match(tokens: ["set"], current: sat, next: nil, strictness: .standard) == nil
    )
  }

  @Test(arguments: ["b", "bb", "be"])
  func aWordThatSoundsLikeALetterIsHeardAsThatLetter(token: String) {
    let bee = Word(text: "bee")
    #expect(WordMatcher.match(tokens: [token], current: bee, next: nil)?.target == .current)
  }

  @Test(arguments: ["ea", "ear", "eara", "earaa", "a"])
  func aOnItsOwnIsHeardThroughItsLetterName(token: String) {
    let word = Word(text: "A")
    #expect(WordMatcher.match(tokens: [token], current: word, next: nil)?.target == .current)
  }

  @Test func aLetterOnlyStandsForItsOwnName() {
    let sea = Word(text: "sun")
    #expect(WordMatcher.match(tokens: ["b"], current: sea, next: nil) == nil)
  }

  @Test func homophonesAreAcceptedWhenGentle() {
    let would = Word(text: "would", homophones: ["wood"])
    #expect(WordMatcher.match(tokens: ["wood"], current: would, next: nil)?.target == .current)
    #expect(
      WordMatcher.match(tokens: ["wood"], current: would, next: nil, strictness: .standard) == nil
    )
    #expect(WordMatcher.match(tokens: ["night"], current: knight, next: nil)?.target == .current)
  }

  @Test func theIsForgivenWhenGentle() {
    let the = Word(text: "The")
    for token in ["a", "uh", "duh", "da", "de", "dee", "thee", "thuh", "they", "then"] {
      #expect(
        WordMatcher.match(tokens: [token], current: the, next: nil)?.target == .current,
        "\(token) was not accepted for the"
      )
    }
    #expect(WordMatcher.match(tokens: ["cat"], current: the, next: nil) == nil)
  }

  @Test func theStaysExactWhenStandard() {
    let the = Word(text: "the")
    #expect(
      WordMatcher.match(tokens: ["the"], current: the, next: nil, strictness: .standard)?.target
        == .current
    )
    #expect(
      WordMatcher.match(tokens: ["duh"], current: the, next: nil, strictness: .standard) == nil
    )
  }

  @Test func readingAheadMarksTheCurrentWordReadToo() {
    #expect(WordMatcher.match(tokens: ["mat"], current: sat, next: mat)?.target == .next)
  }

  @Test func normalizeStripsPunctuationAndCase() {
    #expect(WordMatcher.normalize("The cat, SAT!") == ["the", "cat", "sat"])
  }

  @Test func partialsMustRepeatBeforeTheyCount() {
    var debouncer = PartialDebouncer()
    #expect(debouncer.confirm(tokens: ["sat"], isFinal: false).isEmpty)
    #expect(debouncer.confirm(tokens: ["sat"], isFinal: false) == ["sat"])
  }

  @Test func finalResultsCountImmediately() {
    var debouncer = PartialDebouncer()
    #expect(debouncer.confirm(tokens: ["sat"], isFinal: true) == ["sat"])
  }

  @Test func aWordFromTheStoryMatchesItselfOnceNormalised() {
    let sentence = StoryLibrary.all[0].sentences[0]
    for (index, word) in sentence.words.enumerated() {
      let tokens = WordMatcher.normalize(word.text)
      let match = WordMatcher.match(
        tokens: tokens,
        current: word,
        next: index + 1 < sentence.words.count ? sentence.words[index + 1] : nil
      )
      #expect(match != nil, "\(word.text) did not match itself")
    }
  }

  @Test func digitsAreHeardAsTheirWords() {
    #expect(WordMatcher.normalize("I want 2 go") == ["i", "want", "two", "go"])
    let to = Word(text: "to", homophones: ["two", "too"])
    let heard = WordMatcher.normalize("ran 2")
    #expect(WordMatcher.match(tokens: heard, current: to, next: nil) != nil)
  }

  @Test func apostrophesDoNotStopAMatch() {
    #expect(WordMatcher.normalize("It\u{2019}s big") == ["its", "big"])
    #expect(WordMatcher.match(tokens: ["its"], current: Word(text: "Its"), next: nil) != nil)
  }

  @Test func capitalsAndPunctuationInTheStoryDoNotMatter() {
    let word = Word(text: "Mat.")
    let heard = WordMatcher.normalize("MAT")
    #expect(WordMatcher.match(tokens: heard, current: word, next: nil) != nil)
  }
}
