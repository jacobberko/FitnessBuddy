# Earned App Store submission checklist

Status as of July 28, 2026. The current app plans and adapts locally and has no active AI-service or developer-backend connection.

## Done in the codebase

- [x] **Training insights are local.** The Coach experience presents on-device weekly insights. The shipping app has no relay URL, relay token, API key, or live AI-service request.
- [x] **Duplicate HealthKit save fixed.** The Watch owns the HealthKit save for sessions it starts, and the phone skips a second save for those sessions.
- [x] **iPhone HealthKit permissions match behavior.** The iPhone requests workout read/write only. Heart rate and active energy are limited to the Watch workout experience where they are displayed live.
- [x] **Unused background-delivery capability removed.** Neither app target requests the HealthKit background-delivery entitlement.
- [x] **Privacy manifests added.** iPhone and Watch manifests declare no tracking, no collected data types, and the `UserDefaults` required-reason code `CA92.1`.
- [x] **Export compliance declared.** `ITSAppUsesNonExemptEncryption` is false in the iPhone Info.plist.
- [x] **Purpose strings are truthful and brand-independent.** The iPhone describes recent-workout reading and workout writing; the Watch describes heart-rate/active-energy reading and Watch workout writing.
- [x] **Privacy and support links are in the app.** The You tab links to the stable URLs below.
- [x] **Public legal/support pages are deployed and externally verified.**
  - Privacy: https://jacobberko.com/fitness/privacy/
  - Support: https://jacobberko.com/fitness/support/
  - The former `/privacy/fitnessprivacy.html` page redirects to the new privacy URL.
- [x] **Version metadata is aligned.** The iPhone app, Watch app, and Live Activity extension use version `2.0` and source build `1`; Xcode Cloud assigns the submitted build number.
- [x] **Release code and planner tests have passed locally.** The unsigned Release bundle built successfully with the iPhone app, Watch app, and Live Activity extension embedded. The iPhone 17 Pro simulator run passed all 27 automated test cases, including the deterministic screenshot flow. Repeat the signed archive and TestFlight checks from the exact release state submitted to Apple.

## Required before submission

1. **Confirm App Store Connect accepts Earned.** Earned is the chosen customer-facing name, but existing App Store listings already use the exact title. The name must be successfully reserved or accepted in App Store Connect before submission. This checklist does not represent trademark clearance.

2. **Repair Apple signing and create a signed archive.**
   - Register or confirm these identifiers:
     - `Berko.FitnessBuddy2`
     - `Berko.FitnessBuddy2.watchkitapp`
     - `Berko.FitnessBuddy2.FitnessBuddyLiveActivity`
   - Enable HealthKit only for the iPhone and Watch identifiers. The Live Activity extension does not need HealthKit.
   - Install or allow Xcode to create valid development and App Store distribution profiles for all three identifiers.
   - Ensure a valid Apple Distribution certificate is available.
   - This Mac currently reports zero valid code-signing identities, so an unsigned build can pass while an App Store archive still cannot be produced.
   - Archive the Release scheme, validate it, and upload it to App Store Connect or TestFlight.

3. **Complete App Store Connect metadata.**
   - Earned app name, subtitle, description, keywords, category, copyright, and availability.
   - Current age-rating questionnaire.
   - Privacy Policy URL and Support URL.
   - App Privacy response. For this local-only release, **Data Not Collected** is accurate only while the shipping binary has no analytics, advertising, backend, or live AI transmission.
   - Export-compliance response, review contact, and review notes.

4. **Create required screenshots.**
   - The UI test now captures five deterministic iPhone screens. Re-run and export them from the Earned-branded release state.
   - At least one accepted 6.9-inch iPhone screenshot.
   - At least one accepted 13-inch iPad screenshot because the app supports iPad.
   - Apple Watch screenshots because the Watch app is bundled.
   - Additional sizes are optional when App Store Connect can scale from the required high-resolution set.

5. **Run final physical-device QA.**
   - Complete onboarding and a full workout on iPhone.
   - Pair a real iPhone and Apple Watch; start and complete Watch and phone workouts.
   - Confirm a Watch-started session creates exactly one Apple Health workout.
   - Confirm recent Health workouts read back correctly.
   - Confirm Live Activities on the Lock Screen and Dynamic Island.
   - Confirm the privacy and support links open the published pages.
   - Check supported iPad layouts and orientations.

6. **Use TestFlight before App Review.** Install the uploaded build on real hardware and repeat the release-critical flow once from a clean install.

## Suggested review notes

- No login or account is required.
- The app works without Apple Health; Health access is optional.
- Explain where the reviewer can connect Health, start a workout, inspect history, and find the Watch flow.
- State that the Insights tab presents on-device weekly training signals and that no user data is sent to an AI provider.
- Describe how the app avoids duplicate HealthKit saves for Watch-started sessions.
