# Unshipped Earned AI relay prototype

This Cloudflare Worker is a prototype only. It is not referenced by the Xcode project, the shipping app has no relay setting or network coach, and deploying this directory alone will not enable AI inside the app. The current release uses its deterministic on-device planner and Insights experience.

Do not deploy or market this prototype as a production feature until the iOS integration, abuse controls, consent flow, privacy disclosures, and end-to-end tests are complete.

## Requirements before a future integration

1. Select a currently supported model and revalidate the request and structured-output schema against current official API documentation.
2. Keep the OpenAI API key only in the Worker secret store. Never put it in the iOS project or commit a `.dev.vars` file.
3. Add real abuse protection, rate limiting, request-size limits, and OpenAI project spend limits. A shared token embedded in an iOS binary is extractable and is not sufficient production authentication.
4. Add an explicit in-app consent screen that explains exactly which profile and workout fields leave the device. Do not send Apple Health data unless the feature genuinely requires it and the user has clearly opted in.
5. Update the App Store privacy answers, privacy manifest if applicable, and public privacy policy before enabling transmission.
6. Restore a reviewed iOS client and UI, validate every generated proposal through the deterministic planner guardrails, and add failure, offline, cancellation, and cost-limit tests.

Until those items are complete, this directory is reference code and must remain disconnected from the release target.
