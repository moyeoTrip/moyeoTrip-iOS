import Foundation

#if canImport(Sentry)
import Sentry
#endif

enum SentryBootstrap {
    static func startIfConfigured(bundle: Bundle = .main) {
        guard let dsn = resolvedDSN(bundle: bundle) else { return }

        #if canImport(Sentry)
        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = resolvedEnvironment(bundle: bundle)
            options.releaseName = resolvedValue(key: "SENTRY_RELEASE", bundle: bundle)
            options.tracesSampleRate = NSNumber(value: resolvedTracesSampleRate(bundle: bundle))
            options.sendDefaultPii = false
            options.enableAutoSessionTracking = true
        }
        #else
        #if DEBUG
        print("Sentry DSN is configured; add the Sentry SPM product to enable reporting.")
        #endif
        #endif
    }

    static func resolvedDSN(bundle: Bundle) -> String? {
        let environmentValue = ProcessInfo.processInfo.environment["SENTRY_DSN"]
        let infoValue = bundle.object(forInfoDictionaryKey: "SENTRY_DSN") as? String
        return [environmentValue, infoValue]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.contains("$(") }
    }

    static func resolvedEnvironment(bundle: Bundle) -> String {
        resolvedValue(key: "SENTRY_ENVIRONMENT", bundle: bundle) ?? "development"
    }

    static func resolvedTracesSampleRate(bundle: Bundle) -> Double {
        guard let value = resolvedValue(key: "SENTRY_TRACES_SAMPLE_RATE", bundle: bundle),
              let rate = Double(value) else { return 0 }
        return min(max(rate, 0), 1)
    }

    static func resolvedValue(key: String, bundle: Bundle) -> String? {
        let environmentValue = ProcessInfo.processInfo.environment[key]
        let infoValue = bundle.object(forInfoDictionaryKey: key) as? String
        return [environmentValue, infoValue]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.contains("$(") }
    }
}
