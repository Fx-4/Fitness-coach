# FitCoach iOS — Agent Standards

> Extends the base SwiftUI-Agent-Skill / AGENTS.md at https://github.com/twostraws/SwiftAgents.
> All rules below are **project-specific overrides and additions**. When base and project rules conflict, project rules win.

## Targets
- iOS 18.0+, Swift 6.0+ strict concurrency
- SwiftUI + SwiftData + HealthKit + Vision + Core ML
- No third-party dependencies — Apple frameworks only

---

## How our team writes SwiftUI

- Every view model is `@Observable @MainActor final class`. Never `ObservableObject`.
- Use `Tab` / `TabSection` (iOS 18+) for root navigation — never `.tabItem {}`.
- Use `NavigationStack(path:)` + `navigationDestination(for:)` for all push navigation.
- Color: `foregroundStyle(.primary)` / `foregroundStyle(.secondary)`. **Never** `foregroundColor()`.
- Shape clipping: `clipShape(.rect(cornerRadius: 16))`. **Never** `.cornerRadius()`.
- Spacing: use design-token constants from `DesignTokens.swift`. No raw numeric padding/spacing outside that file.
- Avoid `GeometryReader`; prefer `containerRelativeFrame()` or `visualEffect()`.
- Hide scroll indicators with `.scrollIndicators(.hidden)`.
- Weight: `.bold()`. Never `fontWeight(.bold)`.
- All `Button` actions must include an `accessibilityLabel` when the label is image-only.
- Never use `AnyView`. Use generic helpers or `@ViewBuilder` instead.
- Do not use the single-parameter `onChange` variant; always use the two-parameter form.
- Prefer `Task { }` inside `.task {}` view modifier. Never `DispatchQueue.main.async`.

## How we structure SwiftData models

- Every `@Model` class lives in its own file inside `Models/`.
- All stored properties must have either a default value or be `Optional`. No bare non-optional without default.
- Never use `@Attribute(.unique)`. Enforce uniqueness in service layer.
- All relationships must be `Optional` and use `@Relationship(deleteRule:)` explicitly.
- No computed properties that touch the database inside `@Model`. Put queries in a `Repository` or ViewModel.
- Migrations live in `Models/Migrations/` as `VersionedSchema` + `MigrationPlan`.
- Never expose the `ModelContext` outside of ViewModels and the app entry point.

## How we handle HealthKit privacy

**Privacy checklist — required before any HealthKit PR merges:**
- [ ] `NSHealthShareUsageDescription` is present in Info.plist with plain-language explanation.
- [ ] `NSHealthUpdateUsageDescription` is present if writing any data.
- [ ] HealthKit entitlement is enabled in `fitness_app.entitlements`.
- [ ] `requestAuthorization` is called exactly once — in `HealthKitService.requestPermissions()`, **not** in views.
- [ ] All HK reads happen on a background task; results are published to `@MainActor` via `async/await`.
- [ ] We never store raw HK data in SwiftData — only aggregated or derived values.
- [ ] The app gracefully degrades when HealthKit is unavailable (e.g., iPad without Health app).

## How we write safe concurrency

- All `@Observable` classes are `@MainActor`.
- Background work (HealthKit, Vision inference) runs in `Task.detached(priority:)` or inside a custom `actor`.
- `HealthKitService` is a `@MainActor final class` that spawns detached tasks internally.
- `FormAnalysisService` is a non-isolated `actor` — callers must `await`.
- Never use `Task { @MainActor in }` to escape concurrency checks — fix the root type annotation instead.
- Use `AsyncStream` to bridge callback-based APIs (HK observer queries) to async/await.

## How we write tests

- Unit tests use `Swift Testing` (`@Test`, `#expect`) — **not** `XCTestCase` unless testing async throws from ObjC APIs.
- Test files live in `fitness appTests/` mirroring the source folder structure.
- ViewModels are tested by constructing them with injected mock services conforming to protocols.
- All service protocols live in `Services/Protocols/` so mocks can be substituted in tests.
- HealthKit is never hit in unit tests — use `MockHealthKitService`.
- Minimum coverage target: 80% for `ViewModels/` and `Services/`.

## Workout recommendation rules

- Recommendations are generated client-side — no network calls.
- Difficulty adjusts based on a rolling 7-day average of completed sessions stored in SwiftData.
- Recovery day is injected if the last session was ≥ 600 active calories.

## Camera / Vision / Core ML rules

- Camera access flows through `CameraViewModel` only — no other type calls `AVCaptureSession`.
- `NSCameraUsageDescription` must describe the exercise-form use case explicitly.
- Vision requests run on a background serial queue inside `FormAnalysisService` actor.
- Pose landmarks are mapped to `PoseFeedback` value type before crossing to `@MainActor`.
- The ML model bundle must be < 50 MB; larger models require explicit team approval.

## App Store readiness checklist

- [ ] All `String` literals exposed to users go through `Localizable.xcstrings`.
- [ ] App icon provided in all required sizes via `Assets.xcassets/AppIcon.appiconset`.
- [ ] `CFBundleVersion` auto-incremented by CI; `CFBundleShortVersionString` is semantic.
- [ ] No `DEBUG`-only code paths that affect release behavior.
- [ ] Privacy Manifest (`PrivacyInfo.xcprivacy`) lists HealthKit, Camera, and UserDefaults APIs.
- [ ] App passes `xcodebuild analyze` with zero issues.
- [ ] Tested on real device with HealthKit before submission (simulator lacks HK data).
