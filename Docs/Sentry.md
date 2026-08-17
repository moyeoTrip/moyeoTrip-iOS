# Sentry configuration

The app contains a conditional Sentry bootstrap but no committed DSN or secret.

1. Add `https://github.com/getsentry/sentry-cocoa` to the Xcode project when crash reporting is enabled.
2. Link the `Sentry` product to the `MoyeoTrip` target.
3. Define `SENTRY_DSN`, `SENTRY_ENVIRONMENT`, `SENTRY_RELEASE`, and `SENTRY_TRACES_SAMPLE_RATE` as CI/user-defined build settings or scheme environment variables.
4. Keep real values out of tracked `.xcconfig` and plist files.

Suggested values:

```text
SENTRY_DSN=https://PUBLIC_KEY@SENTRY_HOST/PROJECT_ID
SENTRY_ENVIRONMENT=development|staging|production
SENTRY_RELEASE=moyeotrip-ios@VERSION+BUILD
SENTRY_TRACES_SAMPLE_RATE=0.0 (debug) or an explicitly approved production sample such as 0.1
```

`sendDefaultPii` is disabled. A Sentry organization auth token is only needed for CI symbol upload and must stay in the CI secret store; it is never an app runtime value.

Without the package or a valid DSN the bootstrap is intentionally a no-op.
