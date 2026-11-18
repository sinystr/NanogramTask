# Nanogram: architecture and decisions 🎮

Nanogram is an endless, full-screen feed of playable web games. This document explains what I
built, the decisions behind it, and what each decision costs. For every important choice you'll
find the reasoning, the alternatives I considered, and the price paid.

## ✨ At a glance

- **Platform:** iOS 17+, iPhone, portrait. Swift 6 with complete strict concurrency checking and
  zero warnings. No third-party dependencies.
- **Shape:** a SwiftUI app shell around a UIKit paging scroll view with **exactly 3 recycled game
  views**, each owning one `WKWebView` for the whole session.
- **Memory is bounded by design:** never more than 3 web views, at most 3 loaded game documents,
  and 21 to 30 games in memory however far the user scrolls. Two 500-swipe sessions in section 3,
  one with real games, confirm it: memory levels off instead of growing with the distance
  scrolled.
- **Only the game on screen runs.** Its neighbours are preloaded but paused, and everything
  pauses when the app goes to the background.
- **Tested:** 131 unit tests, 5 UI tests, and a 500-swipe long-session test.

Two words have one fixed meaning throughout the code and this document:
- **Page:** an API page, meaning one JSON response with a batch of games.
- **Position:** one full-screen spot in the feed, counted from 0 at the top.

## ▶️ Running it

Open `Nanogram.xcodeproj` and run the `Nanogram` scheme on an iPhone simulator. The app loads the
real API, one JSON file per page:
`https://gist.githubusercontent.com/jimagination/caed8b3e0e5d17a01a4d06cfc07dd362/raw/page-{n}.json`.

Unit tests (Swift Testing) are in `NanogramTests`, UI tests (XCTest) in `NanogramUITests`. The
UI tests and manual testing use these launch arguments:

| Argument | Effect |
|---|---|
| `-useMockFeed` | Use the mock feed instead of the real API (debug builds only); the `-mock…` arguments need it |
| `-mockDelayMs <n>` | Mock network delay (default 600 ms) |
| `-mockTotalPages <n>` | A feed with this many pages (default: endless) |
| `-mockFailInitialLoad` | The first request fails as "offline"; Retry succeeds |
| `-disableGamePreload` | Don't preload the previous and next games |

---

## 1. 🗺️ The big picture

```
┌──────────────────────────────── SwiftUI ────────────────────────────────┐
│  NanogramApp ──► FeedView ────────────────────────► FeedViewModel       │
│                   │  loading / error / feed          (@Observable,      │
│                   │  scenePhase → app active?          single source    │
│                   ▼                                    of truth)        │
│            GameScrollView  (UIViewControllerRepresentable)    ▲         │
│                   │  state down: GameScrollViewState (a value)│ intents │
│                   │  intents up: closures ────────────────────┘         │
└───────────────────┼─────────────────────────────────────────────────────┘
┌───────────────────▼──────────────────────── UIKit ──────────────────────┐
│  GameScrollViewController   paging UIScrollView, exactly 3 game views   │
│     ├─ PositionSlots        which view shows which position             │
│     ├─ GameScrollGeometry   frames and nearest position                 │
│     ├─ GameLifecyclePolicy  run / pause / unload each game              │
│     └─ 3 × GameView ──► overlay (name, spinner, error + Retry), info bar│
│                    └──► GameRunner ──► WKWebView                        │
└─────────────────────────────────────────────────────────────────────────┘
┌──────────────────────────── Feed state ─────────────────────────────────┐
│  FeedViewModel ──► GamesInMemory    what is known about each kept game  │
│                ├─► LoadedPages      which game indices each page covered│
│                └─► 2 × PageDownloader   one download at a time each     │
└─────────────────────────────────────────────────────────────────────────┘
┌──────────────────────────────── Data ───────────────────────────────────┐
│  GameFeedServiceProtocol ◄── RemoteGameFeedService (real API)           │
│                          ◄── MockGameFeedService   (debug builds only)  │
│  LikedGamesStoreProtocol ◄── LikedGamesStore       (on device)          │
└─────────────────────────────────────────────────────────────────────────┘
```

**State flows down as values; what the user did flows up as calls.** `FeedViewModel` makes
every feed decision: what to load, what to keep in memory, what each position shows. The UIKit
screen doesn't know the view model. It receives a plain `GameScrollViewState` value and reports
what the user did through closures. `GameScrollView` is the only place that connects the two.

---

## 2. 🧭 Key decisions

### 2.1 A UIKit paging scroll view with 3 recycled views, inside a SwiftUI app

**Decision.** The app shell and the simple screens (loading, error) are SwiftUI. The feed is a
plain `UIScrollView` with paging that manages exactly 3 `GameView`s by hand: previous, current
and next. When the user moves one position, `PositionSlots` moves **one** view, and the other
two keep their loaded games.

**Why.** The feed's hard problems are all about controlling expensive web views: how many exist,
when they load, when they pause. That needs exact control over view lifetimes.

**Alternatives considered:**
- **SwiftUI `ScrollView` / `LazyVStack` / `TabView`:** Apple documents only that lazy stacks
  create views when they're needed, not when they release or reuse them
  ([LazyVStack][lazyvstack]). A wrapped `WKWebView` lives exactly as long as SwiftUI keeps its
  view's identity ([Demystify SwiftUI, WWDC21][demystify]), so its lifetime is SwiftUI's
  decision, not ours. In practice this differs between versions: developers report that
  off-screen views are kept on iOS 17, our deployment target, and freed on iOS 18
  ([Apple Developer Forums][lazy-memory]), and that `dismantleUIView` isn't always called when
  a representable is removed ([Apple Developer Forums][dismantle]). With expensive web views
  over a long session, that uncertainty is exactly the memory risk to avoid.

  [lazyvstack]: https://developer.apple.com/documentation/swiftui/lazyvstack
  [demystify]: https://developer.apple.com/videos/play/wwdc2021/10022/
  [lazy-memory]: https://developer.apple.com/forums/thread/775204
  [dismantle]: https://developer.apple.com/forums/thread/724376
- **`UICollectionView`:** recycles cells but owns their lifecycle, prefetching, and when they
  are dequeued. Web views inside cells would start and stop loading on the layout engine's
  schedule, not ours.
- **`UIPageViewController`:** creates and discards child view controllers as you swipe, and its
  scroll view is private, which makes it hard to lock for play mode or tune deceleration.

**Price.** Two UI frameworks and a bridge between them, and frames computed by hand
(`GameScrollGeometry`, which is small and fully unit tested).

### 2.2 Games load only when scrolling stops; neighbours are preloaded and paused

**Decision.** While the finger moves, views are repositioned and show the game's name, but no
web content starts. When scrolling stops, the lifecycle is applied: the current game runs, the
previous and next games are loaded early but paused, and everything else is unloaded.

| | Current | Previous / next | Further away |
|---|---|---|---|
| Browsing | running | loaded, paused | unloaded |
| Playing | running | unloaded | unloaded |
| App in background or covered | paused | loaded, paused | unloaded |

**Why.** Starting web content during a swipe is the main cause of stutter. Preloading both
neighbours means the next swipe, forwards or back, almost always lands on a game that is already
loaded. In play mode the neighbours are unloaded, so the game being played gets all memory and
CPU. When the user closes the game, the neighbours are preloaded again.

**Price.** Up to 3 game documents in memory while browsing instead of 1. A game two positions
back is unloaded and starts from scratch if the user returns to it.

### 2.3 How "paused" works, and why games never run off screen ⏸️

**Decision.** A paused game is loaded but silenced and told it is hidden:
- `setAllMediaPlaybackSuspended(true)` stops `<audio>`, `<video>` and Web Audio, and is lifted
  again on resume.
- `GameVisibilityScript`, injected before any game code runs, takes over `document.hidden` and
  `visibilityState` and fires `visibilitychange`, the standard signal web game engines use to
  stop their loop and sound. Without it, WebKit would report the off-screen neighbours as
  visible, because they sit inside the window just above and below the screen.
- **Every page starts hidden**, so a preloaded game never runs a single frame. The current game
  is revealed only once its document is committed.
- When the app goes to the background or is covered (Control Center, app switcher), `FeedView`
  sees it through `scenePhase` and the current game is paused too. It is paused, not unloaded,
  so the player comes back to the game exactly where they left it.

**Why this approach.** It works with ordinary web games without asking their authors to change
anything, and the media part is enforced by WebKit itself.

**What I learned while testing.** WebKit's `pauseAllMediaPlayback()` looks like the obvious
choice, but it behaves like the user pressing pause. Nothing un-pauses it, so after a resume the
game stays silent. A test that plays a Web Audio tone, pauses and resumes caught this. Only the
suspension API is used now, and the test guards it.

**Price.** Public WebKit API can't freeze a page's JavaScript. A game that ignores
`visibilitychange` keeps its timers running while paused, silently.

### 2.4 One view model owns all feed state

**Decision.** `FeedViewModel` (`@Observable`, `@MainActor`) is the single source of truth: the
loading state, the current position, play mode, likes, and whether the app is active. Views only
display state and report what the user did.

**Why.** Feed decisions depend on each other. What to download depends on where the user is,
what to keep depends on what was downloaded, and what a position shows depends on both. Keeping
them in one place keeps them consistent, and the whole feed can be tested with a mock service and
no UI (33 tests do exactly that).

**The view model decides; small helpers do the mechanics:**
- `GamesInMemory`, an immutable value, records one explicit state for every kept game: loaded,
  missing from its page, or failed to download again. A kept game with no record is waiting to
  be downloaded again.
- Two `PageDownloader`s download pages one at a time: one for new pages, one for forgotten
  pages, so going back never blocks loading new games. A cancelled download never calls back.
- `LoadedPages` remembers which game indices each API page covered.

**The real server or the mock feed** is chosen once, in `AppDependencies`. The mock feed and its
settings (`MockFeedSettings`) exist only in debug builds (`#if DEBUG`), for development and UI
tests. Release builds contain only the real server.

**The bridge to UIKit has no custom observation code.** `GameScrollView` reads the view model
inside `updateUIViewController`. SwiftUI records those reads and calls it again whenever any of
them changes. That is SwiftUI's own mechanism, so there's no hand-written observation loop to
maintain.

**Price.** `FeedViewModel` is still the largest type (about 440 lines), because the feed's
decisions belong together.

### 2.5 A bounded memory window, with forgotten games downloaded again 🧠

**Decision.** After every settle, the view model keeps 10 games behind the current position and
at least 10 ahead, rounded up to the end of that API page: 21 to 30 games. Everything else is
forgotten. When the user comes back to a forgotten game, `LoadedPages` says which page to
download again, using the counts the server actually returned. One such request runs at a time,
separate from loading new pages, and it is cancelled if the user moves away.

**Why.** Memory must not grow with the distance scrolled, and most of a game's size is its HTML.
Games are stored by game index in a dictionary, not an array, so forgetting games never shifts
positions and the scroll offset never needs adjusting.

**Price.** Coming back to a forgotten game costs a request and shows a spinner first. It also
assumes the server's pages are stable. If a page comes back shorter, the games that disappeared
show "Couldn't load this game" instead of a spinner that never ends.

**Alternative.** Keep the small metadata of every game seen and drop only the HTML. The info bar
would then show instantly when coming back. That would be a reasonable next step.

### 2.6 The endless feed ♾️

**Decision.** The next page is requested when the user is 3 or fewer games from the end. While
it loads, or if it fails, one extra **load-more position** after the last game shows a spinner,
or the error with Retry. When the page arrives, its first game takes over that same position, so
the user never moves. When the server has no more pages, the feed loops: positions keep counting
up, and each position maps to a game with `position % loadedGameCount`.

**Why.** The scroll view, the view recycling and the memory window don't need to know the feed
loops. They just see a feed whose scrollable length (`scrollablePositionCount`) keeps growing,
and games forgotten long ago are downloaded again as the loop comes round. A like stays on a
game when it comes round again, because likes are stored by game id.

### 2.7 Treating the API as unreliable 🛡️

**Decision.** The server's JSON is decoded into separate DTO types and turned into the app's
models in one place. Every DTO field is optional, and each game field is decoded on its own with
`try?`, so a missing, `null` or wrong-type value becomes "missing" instead of failing the page.
The app then fills the gaps:

| Missing or invalid | What the user sees |
|---|---|
| `html` | "Couldn't load this game", and they can swipe on |
| `title` | "Untitled game" |
| creator | No "by …" line |
| `id` | A stable stand-in id, so reloading the page finds the same game again |
| a whole game, or a non-object in the list | Keeps its place and shows "Couldn't load this game" |
| `nextPage` | The feed ends and loops |

**Why.** One bad value must never stop the feed. Keeping DTOs separate means a change in the
server's format touches only the networking folder.

**Price.** Server bugs become quiet: a field that's always missing just shows a fallback.
Logging every fallback would be the next step.

### 2.8 Isolation between games 🔒

**Decision.** All web views share one configuration: inline media, no tap required for audio,
and a **non-persistent data store**. Games load with `loadHTMLString(html, baseURL: nil)`, so
each one gets its own opaque origin. Switching games loads `about:blank` first, and late events
from the previous game are ignored by matching each callback to the current navigation. Links
that would navigate away from a game are blocked. A game counts as ready when its document
finishes loading, with a 15-second timeout. There is no JavaScript message channel between the
app and the games, so there is nothing a game can call into.

**Why.** Games are untrusted content. They must not see each other's cookies or storage, leak
anything between launches, or take the user somewhere else.

**Price.** Games that rely on `localStorage` or IndexedDB may fail to save progress.

### 2.9 Every component behind a protocol 🔌

**Decision.** Components with behaviour are used through 11 small protocols that expose only
what their callers need: `FeedViewModelProtocol`, `PageDownloaderProtocol`,
`GameFeedServiceProtocol`, `HTTPClientProtocol`, `LikedGamesStoreProtocol`,
`GameLifecyclePolicyProtocol`, `GameRunnerProtocol`, `GameViewProtocol`,
`GameOverlayViewProtocol`, `GameInfoBarViewProtocol` and `GameCloseButtonProtocol`.
Dependencies are passed in through `init`. Concrete types are created in only three places:
- `AppDependencies` (the composition root)
- `GameScrollView` (which builds the UIKit screen)
- `GameRunnerFactory` (whose job is creating runners)

**Why.** Any part can be replaced or faked in tests by changing one line. Running games with
something other than WebKit would mean one new `GameRunnerProtocol` implementation.

**Where I drew the line.** Plain data (`Game`, `FeedPage`, the content and state values) and
SwiftUI views have no protocols. Data has nothing to replace, and wrapping it in protocols would
cost Swift's automatic equality, which the code and many tests rely on. SwiftUI views are
already composed through SwiftUI's own `View` protocol. `GameRunnerFactory` has none either:
only `GameScrollView` uses it, while building the screen, so no other type would depend on one.

### 2.10 Logic in small immutable values, so it can be tested without UI 🧪

**Decision.** The rules that are easy to get subtly wrong live in small immutable structs with
no UIKit or WebKit:

| Type | Decides |
|---|---|
| `PositionSlots` | Which of the 3 views shows which position |
| `GameScrollGeometry` | Frames, content size, nearest position for an offset |
| `LoadedPages` | Which game indices each API page covered |
| `GamesInMemory` | The state of each kept game: loaded, missing, or failed to download again |
| `GameLifecyclePolicy` | Running, paused or unloaded, for each position |
| `GameOverlayContent` | What covers a game view, and its background; never blank |
| `GameInfoBarContent` | Title, creator, short counts ("285K plays"), like state |

Structs are never changed in place. A change produces a new value that the owner reassigns.

**Why.** Each rule can be tested in milliseconds with plain inputs and outputs, and an
`@Observable` owner notices every change because every change is a reassignment.

### 2.11 Concurrency

- Everything UI-facing is `@MainActor`. There is no mutable state shared between threads.
- Network requests leave the main actor and their results come back to it. Each
  `PageDownloader` runs one download at a time, so the same request never runs twice. The
  downloader is `@MainActor` like the view model, so the view model starts and checks downloads
  with plain calls; only the network request and the decoding run off the main actor.
- A cancelled request never changes state, because the user has moved away from it.
- The mock service is an `actor`. Models and DTOs are `Sendable` values.

### 2.12 Likes stay on the device ❤️

**Decision.** The info bar shows the game's title, creator, plays and likes, and a like button.
The API has no likes endpoint, so likes are saved by game id in `UserDefaults`, behind
`LikedGamesStoreProtocol`. They survive relaunches. The count shown is the server's number plus
the user's own like.

**Price.** Device only, no sync. When the API gets a likes endpoint, only the store changes.

### 2.13 Look and feel 🎨

**Decision.** While something is on its way (a game loading, a forgotten game downloading
again, the next page), the overlay shows soft violet, pink and cyan glows drifting slowly over a
dark base. Game errors use a still blue gradient, so a problem looks different from waiting. The
info bar uses a gradient fade, rounded type, a frosted plays chip and a glass like button with a
small pop and a haptic. The launch screen and the app icon show the Nanogram logo on black, the
same black as the feed, so launching never flashes.

**Why.** The overlay is what the user sees most between games, so it should feel alive rather
than blank. The glows are a few Core Animation layers: they move only while shown, and not at
all when the user has turned on Reduce Motion.

---

## 3. 🚀 Performance: two 500-swipe sessions

**Setup.** `FeedLongSessionTests` launches the app and swipes up fast 500 times, inside XCTest's
`measure` with `XCTMemoryMetric` and `XCTOSSignpostMetric.scrollingAndDecelerationMetric`. It runs
twice:
- **Mock feed:** small static HTML games and a 50 ms local network. This isolates the app's own
  machinery: view recycling, the memory window, page downloads.
- **Real feed:** the real API with real games (scripts, canvases, audio) and real network
  timing, exactly as a user gets it.

`XCTMemoryMetric` sees only the app process, but the games run in separate WebContent
processes. So a small script recorded the footprint of the app and of every WebContent process
every 15 seconds during both runs.

Both ran on 18 November 2026: iPhone 17 Pro simulator (iOS 26.5), Xcode 27.2, Apple M1 Mac with
16 GB. Both tests passed and ended more than 250 positions down the feed.

| Measurement | Mock feed | Real feed |
|---|---|---|
| Test duration | 830 s | 986 s |
| App memory at the end (`Absolute Memory Physical`) | 63.7 MB | 67.6 MB |
| App memory peak (`Memory Peak Physical`) | 64.0 MB | 71.1 MB |
| App memory change over the 500 swipes (`Memory Physical`) | +0.9 MB | −0.9 MB |
| App footprint, sampled every 15 s | 60–61 MB (51 samples) | 62–66 MB (62 samples) |
| WebContent processes | exactly 3 in every sample | exactly 3 in every sample |
| WebContent footprint, all 3 together | 114–122 MB, flat from start to end | grows to ~650 MB in the first 5 minutes, then stays at 645–762 MB |
| One WebContent process | 37–41 MB | 69–283 MB; 215–250 MB once warmed up |
| Average drag-and-deceleration time per swipe | 0.48 s | 0.47 s |

**What they show.**
- **The app itself doesn't grow.** In both runs the app process stayed within a few megabytes
  for all 500 swipes. With real games it even ended slightly lower than it started. View
  recycling, the 21–30 game window and the page downloads cost the same at game 500 as at game
  10.
- **Never more than 3 WebContent processes,** in every one of the 116 samples. The number of
  web views, and so of processes, really is fixed at 3.
- **Real games warm the processes up, then memory levels off.** Each web view keeps its
  WebContent process for every game it shows. With real games, each process grows from about
  70 MB to about 230 MB over the first 5 minutes (roughly the first 150 games), as WebKit's
  JavaScript engine, caches and memory allocator reach their working size. After that, the
  three together stay between 645 and 762 MB for the remaining 11 minutes. The total moves with
  the game on screen, with no steady climb. With the tiny mock games the same processes stay at
  about 40 MB, which shows the growth comes from the games' content, not from the app.

In short: memory depends on how many games are near the user, not on how far they have
scrolled. With real games the app and its 3 WebContent processes together use about
0.7–0.85 GB on the simulator once warmed up.

**What they don't show.** 🔍
- **Hitches.** The simulator doesn't produce hitch or frame-rate metrics; XCTest returned only
  the scroll duration. Hitches have to be measured on a real iPhone, with the same test or the
  Animation Hitches instrument.
- **Device memory.** Simulator footprints are measured on the Mac and are only a guide to what
  an iPhone reports. The trends (flat app, WebContent levelling off) carry over; the absolute
  numbers may not.
- **Behaviour under memory pressure.** The Mac had plenty of memory. On an iPhone, iOS may ask
  the WebContent processes to shrink or end them. The app already handles a process that ends
  (the game shows an error with Retry), but it doesn't yet react to memory warnings.

---

## 4. 📁 Project structure

Folders are organised by feature, not by kind, so changing one feature touches one folder.
Every type is in its own file named after it, and tests use the same folders as the app.

```
Nanogram/
  App/              Entry point, composition root, launch arguments, mock feed settings
  Feed/             The feed screen with its loading and error screens
    GameScroll/     The scrolling games: SwiftUI bridge, UIKit controller, state, geometry, slots
    ViewModel/      Feed state and decisions, games in memory, loaded API pages, page downloads
    Likes/          Saving likes on the device
  Game/             One game view and its settings
    InfoBar/        Title, creator, plays, like button
    Lifecycle/      Running, paused or unloaded
    Overlay/        Name, spinner or error + Retry while a game isn't playable
    Web/            Running a game in a web view: runner, factory, load state, visibility script
  Networking/       Service protocol
    Models/         Game, FeedPage, FeedError
    Remote/         Real server: HTTP client, DTOs, decoding
    Mock/           Fake feed for development and UI tests (debug builds only)
  Shared/           Logging and signposts
NanogramTests/      Same folders as the app
NanogramUITests/    Feed UI tests and the long-session test
```

The code follows a few conventions for readability: one step per line with named values, plain
loops for anything non-trivial, and names that say what something is. Words have one meaning
throughout: "page" is always an API page, and a spot on screen is a "position".

---

## 5. ✅ Testing

| Level | What is covered | How |
|---|---|---|
| Rules | View recycling, geometry, loaded pages, games in memory, lifecycle policy (including play mode and background), overlay and info bar content, decoding (missing and wrong-type values), error mapping, launch arguments | Swift Testing, plain values, milliseconds |
| Feed | First load, pagination, the load-more position, failures and Retry, the memory window, reloading forgotten games, looping, likes, app activity | Swift Testing with a mock service, a scripted service and an in-memory likes store |
| Web | `GameRunner` with a real `WKWebView`: ready, timeout, crash and Retry, unload, isolation between games, hidden and visible, Web Audio silenced when paused and back on resume | Swift Testing on the simulator |
| UI | Loading → feed, error → Retry → feed, swiping, play mode and Close, looping | XCTest on the mock feed |
| Long session | 500 fast swipes with memory and scroll metrics, on the mock feed and on the real API (section 3) | XCTest `measure` |

Logging uses `os.Logger` with categories (`feed`, `game`, `network`, `lifecycle`). An
`OSSignposter` interval measures every game load and shows up in Instruments.

---

## 6. 🔭 Known limitations and next steps

- **Hitches not measured yet.** The next step is the long session on a real iPhone with the
  Animation Hitches and Allocations templates, ideally in CI with baselines that fail on
  regressions.
- **No reaction to memory warnings.** Dropping the preloaded neighbours on a warning would be a
  small change in the lifecycle policy.
- **WebContent processes keep their warmed-up size.** With real games each settles at about
  230 MB on the simulator. If that turns out too much on older iPhones, replacing a web view
  (and so its process) every few hundred games, or on a memory warning, would bring it back to
  its starting size.
- **Coming back to a forgotten game shows a spinner first.** Keeping metadata, or a snapshot of
  the game's last frame, would show something instantly.
- **Paused games are paused by convention.** A small documented pause/resume protocol for game
  authors, over a WebKit message channel, would make it reliable for every game.
- **Lenient decoding hides server problems.** Logging every fallback would surface them.
- **Not run on an iOS 17 device or runtime.** The deployment target is verified by the compiler
  only.
