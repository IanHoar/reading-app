import Content
import Foundation

public enum WordMatcher {
  public enum Strictness: String, Codable, Hashable, Sendable, CaseIterable {
    case gentle
    case standard
  }

  public enum Target: Hashable, Sendable {
    case current
    case next
  }

  public struct Match: Hashable, Sendable {
    public var target: Target
    public var token: String

    public init(target: Target, token: String) {
      self.target = target
      self.token = token
    }
  }

  static let soundsAlike: [String: Set<String>] = [
    "the": ["a", "uh", "duh", "da", "de", "dee", "thee", "thuh", "they", "then"],
    "a": ["ay", "ah", "eh", "uh", "ea", "ear", "eara", "era", "hey", "oh", "o"],
    "bee": ["be", "bea"],
    "on": ["oh", "awn", "ahn", "own"]
  ]

  static let letterNames: [String: Set<String>] = [
    "a": ["a"], "b": ["bee", "be"], "c": ["see", "sea"], "d": ["dee"], "g": ["gee"],
    "i": ["i", "eye"], "j": ["jay"], "k": ["kay"], "o": ["oh", "owe"], "p": ["pea", "pee"],
    "q": ["queue"], "r": ["are"], "t": ["tea", "tee"], "u": ["you"], "y": ["why"]
  ]

  static let vowels = Set("aeiouy")
  static let voicing: [Character: Character] = [
    "t": "d", "d": "t", "p": "b", "b": "p", "k": "g", "g": "k", "s": "z", "z": "s"
  ]

  static let spelledNumbers: [String: String] = [
    "0": "zero", "1": "one", "2": "two", "3": "three", "4": "four", "5": "five",
    "6": "six", "7": "seven", "8": "eight", "9": "nine", "10": "ten"
  ]

  public static func normalize(_ transcript: String) -> [String] {
    transcript
      .lowercased()
      .replacingOccurrences(of: "\u{2019}", with: "")
      .replacingOccurrences(of: "'", with: "")
      .components(separatedBy: .whitespacesAndNewlines)
      .map { $0.trimmingCharacters(in: CharacterSet.alphanumerics.inverted) }
      .filter { !$0.isEmpty }
      .map { spelledNumbers[$0] ?? $0 }
  }

  public static func match(
    tokens: [String],
    current: Word,
    next: Word?,
    strictness: Strictness = .gentle
  ) -> Match? {
    let tail = tokens.suffix(3)
    guard !tail.isEmpty else { return nil }

    if let next {
      for token in tail.reversed() {
        guard accepts(token: token, target: next, strictness: strictness) else { continue }
        return Match(target: .next, token: token)
      }
    }
    for token in tail.reversed() {
      guard accepts(token: token, target: current, strictness: strictness) else { continue }
      return Match(target: .current, token: token)
    }
    return nil
  }

  static func collapsed(_ token: String) -> String {
    var result = ""
    for character in token where character != result.last { result.append(character) }
    return result
  }

  static func accepts(token: String, target: Word, strictness: Strictness) -> Bool {
    let text = normalize(target.text).joined()
    guard !token.isEmpty, !text.isEmpty else { return false }
    let token = token.count > 1 && collapsed(token).count == 1 ? collapsed(token) : token
    if letterNames[token]?.contains(text) == true { return true }

    if token == text { return true }
    if text.count >= 4, levenshtein(token, text) <= 1 { return true }
    guard strictness == .gentle else { return false }

    let squeezed = collapsed(token)
    for heard in Set([token, squeezed]) where heard.count == text.count {
      if heard.prefix(2) == text.prefix(2) { return true }
    }
    if target.homophones.contains(where: { $0.lowercased() == token }) { return true }
    if soundsAlike[text]?.contains(token) == true { return true }
    if soundsAlike[text]?.contains(collapsed(token)) == true { return true }
    return soundsLikeShortWord(token, text) || soundsLikeShortWord(squeezed, text)
  }

  static func soundsLikeShortWord(_ token: String, _ text: String) -> Bool {
    let target = Array(text), heard = Array(token)
    let opens = target.first == "y" || target.first.map { !vowels.contains($0) } == true
    guard
      target.count == 3, opens, vowels.contains(target[1]),
      !vowels.contains(target[2]), (3...4).contains(heard.count),
      let first = heard.first, let last = heard.last, first == target[0],
      last == target[2] || last == voicing[target[2]]
    else { return false }
    return heard.dropFirst().dropLast().allSatisfy(vowels.contains)
  }

  static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
    let lhs = Array(lhs), rhs = Array(rhs)
    guard !lhs.isEmpty else { return rhs.count }
    guard !rhs.isEmpty else { return lhs.count }

    var previous = Array(0...rhs.count)
    var current = [Int](repeating: 0, count: rhs.count + 1)
    for i in 1...lhs.count {
      current[0] = i
      for j in 1...rhs.count {
        let substitution = previous[j - 1] + (lhs[i - 1] == rhs[j - 1] ? 0 : 1)
        current[j] = min(previous[j] + 1, current[j - 1] + 1, substitution)
      }
      swap(&previous, &current)
    }
    return previous[rhs.count]
  }
}
