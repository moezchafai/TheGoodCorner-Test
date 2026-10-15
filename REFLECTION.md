# Reflection

This document explains how I worked with AI, the decisions I owned, and the ambiguities I encountered. It follows the four points required by the README.

---

## 1. AI Usage

### Tools used

| Tool | Purpose |
|------|---------|
| **Claude** (chat) | Reviewing my architecture diagram; first drafts of each layer (Domain, Data, UI) and of the tests; Git commands and incident diagnosis; reviewing my own files (`Endpoint`, `NetworkError`, `ListingListViewModel`, tests) |
| **DeepSeek** (chat) | Debugging and understanding Xcode error messages; cross-checking answers from Claude on technical questions (e.g., `@MainActor` on ViewModels, Combine cancellation patterns) |
| **Stitch** (Google) | Generating UI mockups for the list, detail, and favorites screens. I provided screenshots of my inspiration and Stitch gave me ready-to-implement screens that I adapted |
| **Gemini** | Generating the app icon. I kept the icon after a few iterations on the prompt |
| **Xcode 15.2 + iPhone 15 Pro simulator** | Build, test (`Cmd + U`, server off), visual verification |
| **curl + local server** | Verifying the real API contract before writing code that depends on it |
| **Git / GitHub** | One branch per feature, merges into `main`, checking `server/` before each push |

### AI suggestions I corrected or rejected

I used AI as a **sounding board**: it proposed, I decided. I kept control of compiling and running every piece of code, verifying assumptions against the real server, choosing the scope, and reading every file.

**Corrected: `URLSession.dataTask` with closures.**

- **Proposed:** the network layer built on `URLSession.dataTask(with:completionHandler:)` with closures.
- **Corrected to:** Combine's `dataTaskPublisher(for:)`.
- **Why:** it integrates naturally with the reactive architecture already in place, error propagation is cleaner with `.mapError`, and tests don't need `XCTestExpectation` boilerplate for most cases.

**Corrected: generic `Error`.**

- **Proposed:** handle network errors with the generic `Error` type.
- **Corrected to:** a typed `NetworkError` enum (`invalidURL`, `invalidResponse`, `badStatus(Int)`, `decodingFailed`, `transport`) conforming to `LocalizedError` and `Equatable`.
- **Why:** precise user-facing messages via `errorDescription`, and deterministic tests via `XCTAssertEqual(error, .decodingFailed)`.

**Corrected: default `page=1&limit=20` in the API layer.**

- **Proposed:** an API layer that always requested `page=1&limit=20`.
- **Problem:** category filtering is client-side (the API has no `category_id` parameter). With 20 out of 300 listings, a category like "Immobilier" would have looked almost empty. I noticed it during review, then confirmed with `curl`: `GET /listings` without parameters returns `total: 300`.
- **Corrected to:** `page`, `limit`, and `query` are optional and absent by default. Pagination was added later, deliberately (50 listings per page), with automatic loading of the next page when a filter leaves too few results.
- **Guard:** a test asserts the exact URL `/listings`, without any parameter.

**Rejected: rewriting Git history.**

- **Context:** an imprudent `git add .` had committed a backup folder (`TheGoodCorner-OLD`) and `.DS_Store` files.
- **Proposed:** reset the history and force-push to clean it.
- **Rejected:** I kept the history and fixed it with cleanup commits (folder removed, `.gitignore`, files removed from the index).
- **Why:** history is a trace of progress, and force-pushing is too easily abused. What matters is the final state, which I verified (`git ls-files`).

---

## 2. Architectural decisions I owned

| Decision | Alternative rejected | Reason |
|----------|---------------------|--------|
| **Clean Architecture in three layers** (Domain, Data, UI), with protocols at the boundaries (`HTTPClient`, `ListingAPI`, `ListingRepository`, `FavoritesRepository`) | Logic in the ViewModels, `URLSession` called directly | The whole logic is testable without a server. This is the architecture diagram I designed first, and I kept it |
| **Protocol-based `HTTPClient`** separated from its implementation (`URLSessionHTTPClient`) | A single concrete type | Allows injecting a `MockHTTPClient` in tests; deterministic tests without a network |
| **Combine for the Repository, `async/await` for tests** | `@Observable`, `async/await` everywhere | `@Observable` requires iOS 17 (target is iOS 16). Combine provides `debounce`, `CombineLatest`, and request cancellation. Tests use `async/await` via a `Publisher+Sync` helper |
| **`APIConfiguration` to centralize the base URL** | Hardcode the URL in each file | One single place to change the server address |
| **Coordinator pattern for navigation** (`AppRoute`, `AppCoordinator`, `AppCoordinatorView`) | Navigation declared in each view | Views no longer know their destinations; `AppCoordinator` is testable in isolation (2 unit tests) |
| **Typed errors: `NetworkError`** is `LocalizedError`, with `decodingFailed` distinct from `badStatus` | Generic `Error` | User-readable messages; a server failure is not confused with unreadable JSON |
| **Category filter client-side, search server-side** | Everything client-side or everything server-side | The API handles `?query=` but has no category parameter |
| **Favorites in `UserDefaults`**, behind `FavoritesRepository`, with a full copy of the listing | SwiftData (iOS 17), Core Data (overkill), id-only | Small list without queries. With search and pagination, a favorite may no longer be in the loaded list |
| **Unit tests only**; UI test target removed | XCUITest | A UI test launches the real app, so it depends on the server |
| **Test scope reduced from ~50 to 20 high-value tests** | Keep every test written | Each remaining test maps to a distinct README example (decoding, request building, filtering, view model states). Quality over quantity |

---

## 3. Ambiguities in the prompt or API

### 3.1 In the prompt

| Ambiguity | What I decided |
|-----------|----------------|
| Category filter required, but the API has no category parameter | Client-side filter. With pagination: automatic loading of the next page while the filter leaves too few results, stopping at the first error to avoid a loop |
| "Intentional empty state": which one? | Three distinct cases, each with its own message and action: no listings, empty category, no search results |
| What if `/categories` fails? | Nothing specified. Listings and categories are loaded together (`Zip`): a single error state. Assumed tradeoff |
| **Number of tests (3-5 requested vs 20 delivered)** | The README asks for "at least three to five cases". I initially wrote ~50, then audited down to **20 tests**, each mapping to a distinct README example. I chose quality over quantity |
| **"At most one bonus"** | See section 4 |

### 3.2 In the API (verified with `curl`)

| Observation | Handling |
|-------------|----------|
| **Date format not specified** | The API returns `"2019-11-06T11:22:35Z"`. I used `ISO8601DateFormatter` with `.withInternetDateTime`. The displayed date is localized in French via a `dateText` property |
| `images_url` can be an empty object `{}` | Optional fields in the DTO; placeholder in the UI |
| Some images point to `poisoned-image.jpg` (valid URL, loading fails) | `.failure` phase of `AsyncImage`: same placeholder. A `nil` URL is handled separately, because `AsyncImage` would stay in an infinite loading state |
| Relative image paths (`/images/ad-small/...`) | Prefixed with the server address |
| Order: urgent first, then most recent | Kept as is: no sorting on the app side, and a test guarantees it |
| `GET /listings` without parameters | Returns all 300 listings (`total: 300`, `has_more: false`) |
| Search ignores accents (`velo` finds "vélo") | No handling on the app side |
| `vélo` with the raw accent returns nothing; `v%C3%A9lo` works | `URLQueryItem` encodes the text; a test guarantees it |
| Search without result: `200` with `items: []` | Empty state "Aucun résultat", not an error |

### 3.3 Environment and starter

- **Project rejected by Xcode 15.2.** The starter `.xcodeproj` is in Xcode 16 format (`objectVersion = 77`) and Xcode 15.2 replies "didn't find classname for 'isa' key". I recreated it, keeping the iOS 16 target and the ATS exception for local networking, and copied the sources.
- **`server/Package.resolved` regenerated by SPM.** `swift run` had rewritten it with my local Swift tool. I restored it in a dedicated commit (`git checkout upstream/main -- server/Package.resolved`), and I check `git diff upstream/main -- server` before each push: the output must stay empty. I added the file to `.gitignore` to avoid recurrence.

---

## 4. Bonus strategy

The README states: *"If you choose to do bonus work, pick at most one option."*

I chose **Search** as the primary bonus, because it matches the README requirements point by point:
- real-time search,
- debounce (300 ms),
- cancel in-flight requests when the query changes,
- handle empty and error states.

Beyond Search, I added UX extensions to deliver a complete product experience:
- **Infinite scroll pagination** (with `hasMore`, page merging without duplicates, and retry).
- **Persistent favorites** (via `UserDefaults`), with a dedicated screen and a badge in the toolbar.
- **Dark mode toggle** persisted with `@AppStorage`.
- **Floating card design** with glassmorphism hearts.

I **assume this tradeoff**: the README recommends one bonus, and I extended the product further to demonstrate end-to-end quality. If I were to redo this test, I would probably focus only on Search to strictly follow the brief. I document this choice transparently because I believe **shipping a polished product** matters more than strictly minimizing scope.

---

## 5. Running the project

1. Start the server: `cd server && swift run` (listens on `http://localhost:8080`).
2. Open `TheGoodCorner/TheGoodCorner.xcodeproj` with Xcode 15.2 or later, choose an iPhone simulator (iOS 16 or later), then `Cmd + R`.
3. Run the tests with `Cmd + U`. The server is not required.