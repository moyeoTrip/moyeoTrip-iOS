# Sentry configuration

The `Sentry` Swift Package product is linked to the `MoyeoTrip` target and the app initializes it at launch when a DSN is configured locally. `Secrets.xcconfig` is ignored by Git and is included by `App.xcconfig` for this purpose.

`SENTRY_DSN`, `SENTRY_ENVIRONMENT`, `SENTRY_RELEASE`, and `SENTRY_TRACES_SAMPLE_RATE` can be set in `Secrets.xcconfig`, as CI/user-defined build settings, or as scheme environment variables.

`sendDefaultPii` is disabled. A Sentry organization auth token is only needed for CI symbol upload and must stay in the CI secret store; it is never an app runtime value.

Without the package or a valid DSN the bootstrap is intentionally a no-op.
