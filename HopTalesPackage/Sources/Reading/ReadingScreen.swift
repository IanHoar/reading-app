import ComposableArchitecture2
import Content
import Dependencies
import DesignSystem
import SpeechRecognition
import SwiftUI
import World

@Feature public struct Reading {
  public static let settleAfterSpeaking = Duration.milliseconds(300)
  public static let offerHelpAfter = Duration.seconds(6)
  public static let relistenAfterEnd = Duration.milliseconds(150)
  public static let relistenAfterFailure = Duration.seconds(1)

  public init() {}

  public struct State: Identifiable {
    public struct Recognised: Equatable, Sendable {
      public var count: Int
      public var sentenceIndex: Int
      public var stars: Int
      public var wordIndex: Int
    }

    public enum Completed: Equatable, Sendable {
      case sentence(index: Int)
      case story(stars: Int)
    }

    public var authorization: SpeechClient.Authorization?
    public var bigWords: Set<WordRef> = []
    public var friend = Friend.hare
    public var look: String?
    public var treat: StoryTreat?
    public var completed: Completed?
    public var completionCount = 0
    public var isActive = true
    public var journeyMoments: [JourneyMoment] = []
    public var hasTriedItOn = false
    public var isConfirmingStop = false
    public var listeningEpoch = 0
    public var isSpeaking = false
    public var recognised: Recognised?
    public var sentenceIndex = 0
    public var stars = 0
    public var story: Story
    public var strictness: WordMatcher.Strictness = .gentle
    public var usedHelp = false
    public var wordIndex = 0

    public init(
      story: Story, friend: Friend = .hare, bigWords: Set<WordRef> = [], treat: StoryTreat? = nil
    ) {
      self.story = story
      self.friend = friend
      self.bigWords = bigWords
      self.treat = treat
    }

    public var currentWord: Word? {
      sentence?.words[safe: wordIndex]
    }

    public var nextWord: Word? {
      sentence?.words[safe: wordIndex + 1]
    }

    public var sentence: Sentence? {
      story.sentences[safe: sentenceIndex]
    }

    public var worldProgress: Double {
      Double(wordsCompleted) * Story.stepPerWord
    }

    public var mood: Mood {
      story.mood(atSentence: min(sentenceIndex, story.sentences.count - 1))
    }

    public var wordsCompleted: Int {
      story.sentences.prefix(sentenceIndex).reduce(0) { $0 + $1.words.count } + wordIndex
    }
  }

  public enum Action {
    case authorizationResolved(SpeechClient.Authorization)
    case backTapped
    case backToStoriesTapped
    case continueTapped(Story)
    case currentWordTapped
    case readAgainTapped
    case helpOffered
    case keepReadingTapped
    case tryItOnTapped(Friend)
    case momentDismissed
    case speechFinished
    case scenePhaseChanged(isActive: Bool)
    case speechResult(tokens: [String], isFinal: Bool)
  }

  @FeatureState var debouncer = PartialDebouncer()
  @FeatureState var savedStars = 0
  @FeatureState var chimedSentence: Int?
  @FeatureState var profile = Profile()
  @FeatureState var wordsHelped: Set<WordRef> = []
  @FeatureState var wordsRead: Set<WordRef> = []
  @Dependency(ProfileStore.self) var profileStore
  @Dependency(ProgressStore.self) var progressStore
  @Dependency(SoundClient.self) var sound
  @Dependency(SoundPreference.self) var soundPreference
  @Dependency(SpeechClient.self) var speechClient
  @Dependency(StrictnessPreference.self) var strictnessPreference
  @Dependency(SpeechLog.self) var speechLog

  private func persist(_ state: State) {
    var progress = progressStore.load()
    progress.stars += state.stars - savedStars
    progress.completedSentences[state.story.id] = max(
      progress.completedSentences[state.story.id] ?? 0,
      state.sentenceIndex
    )
    progress.wordsRead[state.story.id] = max(
      progress.wordsRead[state.story.id] ?? 0,
      state.wordsCompleted
    )
    progressStore.save(progress)
    savedStars = state.stars
  }

  public var body: some Feature {
    Update { state, action in
      switch action {
      case let .authorizationResolved(authorization):
        state.authorization = authorization

      case .backTapped:
        guard case .story = state.completed else {
          state.isConfirmingStop = true
          break
        }
        store.addTask { try store.send(.backToStoriesTapped) }

      case .readAgainTapped:
        state.sentenceIndex = 0
        state.wordIndex = 0
        state.stars = 0
        state.usedHelp = false
        state.journeyMoments = []
        wordsHelped = []
        wordsRead = []
        state.completed = nil
        state.recognised = nil
        savedStars = 0
        chimedSentence = 0
        debouncer.reset()

      case .backToStoriesTapped:
        state.isConfirmingStop = false

      case .keepReadingTapped:
        state.isConfirmingStop = false

      case .continueTapped:
        break

      case .tryItOnTapped:
        state.hasTriedItOn = true

      case .momentDismissed:
        state.hasTriedItOn = false
        guard let index = state.journeyMoments.firstIndex(where: \.isCallout) else { break }
        state.journeyMoments.remove(at: index)

      case .currentWordTapped, .helpOffered:
        guard let word = state.currentWord?.text, !state.isSpeaking else { break }
        wordsHelped.insert(WordRef(sentence: state.sentenceIndex, word: state.wordIndex))
        state.usedHelp = true
        state.isSpeaking = true
        let voice = profile.voiceID
        store.addTask {
          await speechClient.speak(word, voice)
          try? await Task.sleep(for: Reading.settleAfterSpeaking)
          try store.send(.speechFinished)
        }

      case .speechFinished:
        state.isSpeaking = false
        debouncer.reset()

      case let .scenePhaseChanged(isActive):
        guard isActive != state.isActive else { break }
        state.isActive = isActive
        state.listeningEpoch += 1

      case let .speechResult(tokens, isFinal):
        guard !state.isSpeaking else {
          log(tokens, isFinal: isFinal, outcome: .speaking, in: state)
          break
        }
        let eligible = debouncer.confirm(tokens: tokens, isFinal: isFinal)
        let match = state.currentWord.flatMap { current in
          WordMatcher.match(
            tokens: eligible,
            current: current,
            next: state.nextWord,
            strictness: state.strictness
          )
        }
        let outcome: SpeechLogEntry.Outcome = switch match?.target {
        case .current: .current
        case .next: .next
        case nil: eligible.isEmpty ? .waiting : .none
        }
        log(tokens, isFinal: isFinal, outcome: outcome, in: state)
        guard let match else { break }
        let sentenceBefore = state.sentenceIndex
        let starsBefore = state.stars
        let readIndex = state.wordIndex
        let count = match.target == .next ? 2 : 1
        for offset in 0..<count {
          wordsRead.insert(WordRef(sentence: sentenceBefore, word: readIndex + offset))
        }
        state.advance(by: count)
        state.recognised = Reading.State.Recognised(
          count: (state.recognised?.count ?? 0) + 1,
          sentenceIndex: sentenceBefore,
          stars: state.stars - starsBefore,
          wordIndex: readIndex
        )

        if state.sentenceIndex != sentenceBefore {
          debouncer.reset()
          persist(state)
          if case .story = state.completed { finish(&state) }
        }
      }
    }

    .onMount(id: [store.sentenceIndex, store.listeningEpoch]) { state in
      guard state.isActive else { return }
      state.strictness = strictnessPreference.load()
      profile = profileStore.load() ?? Profile()
      let locale = profile.accent.locale
      let completed = state.completionCount > 0 && chimedSentence != state.sentenceIndex
      if completed { chimedSentence = state.sentenceIndex }
      let celebrates = completed && soundPreference.load()
      guard let sentence = state.sentence else {
        if celebrates { store.addTask { await sound.sentenceCompleted() } }
        return
      }
      let contextualStrings = sentence.words.map(\.text)
      let known = state.authorization
      if celebrates { store.addTask { await sound.sentenceCompleted() } }
      store.addTask {
        let authorization: SpeechClient.Authorization
        if let known {
          authorization = known
        } else {
          authorization = await speechClient.requestAuthorization(locale)
          try store.send(.authorizationResolved(authorization))
        }
        guard authorization == .authorized else { return }
        var heardAt = ContinuousClock.now
        while !Task.isCancelled {
          guard let events = try? await speechClient.listen(contextualStrings, locale) else {
            try await Task.sleep(for: Reading.relistenAfterFailure)
            continue
          }
          for await event in events {
            switch event {
            case let .partial(tokens):
              heardAt = .now
              try store.send(.speechResult(tokens: tokens, isFinal: false))
            case let .final(tokens):
              heardAt = .now
              try store.send(.speechResult(tokens: tokens, isFinal: true))
            case .silence:
              guard ContinuousClock.now - heardAt >= Reading.offerHelpAfter else { break }
              heardAt = .now
              try store.send(.helpOffered)
            }
          }
          try await Task.sleep(for: Reading.relistenAfterEnd)
        }
      }
    }
  }
}

extension Reading {
  func log(
    _ tokens: [String], isFinal: Bool, outcome: SpeechLogEntry.Outcome, in state: State
  ) {
    speechLog.record(
      SpeechLogEntry(
        story: state.story.id,
        sentence: state.sentenceIndex,
        word: state.currentWord?.text ?? "",
        heard: tokens,
        isFinal: isFinal,
        outcome: outcome
      )
    )
  }

  func finish(_ state: inout State) {
    var progress = progressStore.load()
    let helped = wordsHelped.intersection(wordsRead).count
    let helpRate = wordsRead.isEmpty ? 0 : Double(helped) / Double(wordsRead.count)
    let collected = state.treat.flatMap { treat in
      wordsRead.contains(treat.word)
        ? CollectedTreat(
          friend: treat.friend,
          isTrail: treat.isTrail,
          isGolden: !treat.isTrail && helpRate <= Levels.goldenHelpRate
        )
        : nil
    }
    let result = StoryResult(
      storyID: state.story.id,
      wordsRead: wordsRead.count,
      bigWordsRead: wordsRead.intersection(state.bigWords).count,
      helpedWords: helped,
      treat: collected
    )
    state.journeyMoments = progress.journey.record(result)
    if let collected { state.journeyMoments += progress.collect(collected) }
    progressStore.save(progress)
  }

}

public struct ReadingScreen: View {
  let store: StoreOf<Reading>

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  @Environment(\.scenePhase) private var scenePhase

  public init(store: StoreOf<Reading>) {
    self.store = store
  }

  private var metrics: Metrics {
    horizontalSizeClass == .regular && verticalSizeClass == .regular ? .pad : .phone
  }

  public var body: some View {
    GeometryReader { outer in
      let chrome = ReadingGeometry(metrics: metrics, size: outer.size)
      ZStack(alignment: .topLeading) {
        GeometryReader { proxy in
          PathStage(store: store, geometry: ReadingGeometry(metrics: metrics, size: proxy.size))
        }
        .ignoresSafeArea()
        BackChip(geometry: chrome) { store.send(.backTapped) }
          .padding(.leading, chrome.path(18) - (chrome.path(44) - chrome.path(38)) / 2)
          .padding(.top, chrome.path(4))
        #if DEBUG
          DebugControls(store: store)
            .position(x: outer.size.width / 2, y: chrome.path(96))
        #endif
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .modifier(ReadingPanels(store: store))
    .task(id: store.completionCount) {
      guard store.completionCount > 0, case .sentence = store.completed else { return }
      Haptics.sentenceCompleted()
    }
    .onChange(of: scenePhase) { _, phase in
      store.send(.scenePhaseChanged(isActive: phase != .background))
    }
    .task(id: store.recognised) {
      guard store.recognised != nil else { return }
      Haptics.wordRecognised()
    }
  }
}
