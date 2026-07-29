# Earned

Earned is a local-first adaptive training app for iPhone and Apple Watch. It builds a personalized weekly strength plan, logs every set, advances successful lifts, and tracks PRs and training volume — entirely on device, with no account and no server. Earned is the chosen customer-facing name; its exact App Store name must still be accepted in App Store Connect before submission because existing listings use the same title.

## Run the app

1. Open `FitnessBuddy2.xcodeproj` in Xcode 26 or newer.
2. Select the `FitnessBuddy2` scheme and an iOS 18+ device or simulator.
3. Choose your own signing team for the iPhone app, Live Activity extension, and Watch app.
4. On a physical device, enable HealthKit for the app and Watch targets if Xcode asks to refresh signing capabilities.

The app works without an account or network connection. Its deterministic local engine generates the first week and advances successful lifts after completed workouts.

## On-device training insights

The **INSIGHTS** tab is a finished, offline analysis of recent sessions, set quality, training volume, recovery timing, and the load decisions made by the deterministic program engine. The shipping app makes no network requests and does not present those local rules as a conversational AI service.

The plan-validation model and its tests (`applyCoachResponse`, `validatedCoachPlan`) remain in `WorkoutData.swift`, and an unshipped Cloudflare Worker prototype lives in [`AIBackend`](AIBackend). Neither is referenced by the app. Any future networked coach would require a deployed relay with rate and spend limits, explicit in-app consent before training or health context is transmitted, and updated App Store privacy disclosures and privacy policy.

## Apple integrations

- **HealthKit:** requests permission in **YOU**, saves completed strength workouts, and reads back the workout list. The iPhone requests only workout read/write — heart rate and active energy are requested on the Watch alone, where they are actually used.
- **Apple Watch:** receives the weekly plan, respects the user’s weight units and equipment increments, logs weight/reps/RIR offline, records a native HealthKit workout with live heart rate and active energy, and syncs lifecycle/set events back to iPhone. The Watch owns the HealthKit save for sessions it starts (`WorkoutSession.recordingOwner`); the phone skips its own save for those so Health never receives a duplicate. Active Watch workouts recover after a relaunch and can be saved early or discarded.
- **Live Activities:** starts for iPhone- or Watch-originated workouts, renders set progress and rest countdowns on the Lock Screen and Dynamic Island, reconnects after an app relaunch, and dismisses orphaned sessions.
- **Haptics:** marks navigation, completed sets, PRs, rest completion, and workout completion on supported hardware.

Strength-specific set load and rep details stay in the app because HealthKit’s workout model does not represent those fields directly.
