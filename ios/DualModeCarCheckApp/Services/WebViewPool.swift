import Foundation
import WebKit

@MainActor
class WebViewPool {
    static let shared = WebViewPool()

    private var available: [WKWebView] = []
    private var inUse: Set<ObjectIdentifier> = []
    private let maxPoolSize: Int = 10
    private let logger = DebugLogger.shared
    private(set) var processTerminationCount: Int = 0

    var activeCount: Int { inUse.count }
    var availableCount: Int { available.count }
    var totalCount: Int { inUse.count + available.count }

    func acquire(stealthEnabled: Bool = false, viewportSize: CGSize = CGSize(width: 390, height: 844), networkConfig: ActiveNetworkConfig = .direct) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        NetworkSessionFactory.shared.configureWKWebView(config: config, networkConfig: networkConfig)

        if stealthEnabled {
            let stealth = PPSRStealthService.shared
            let profile = stealth.nextProfile()
            let userScript = stealth.createStealthUserScript(profile: profile)
            config.userContentController.addUserScript(userScript)

            let wv = WKWebView(frame: CGRect(origin: .zero, size: CGSize(width: profile.viewport.width, height: profile.viewport.height)), configuration: config)
            wv.customUserAgent = profile.userAgent
            inUse.insert(ObjectIdentifier(wv))
            logger.log("WebViewPool: acquired stealth WKWebView network=\(networkConfig.label) (active:\(inUse.count) pool:\(available.count))", category: .webView, level: .trace)
            return wv
        }

        let wv = WKWebView(frame: CGRect(origin: .zero, size: viewportSize), configuration: config)
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        inUse.insert(ObjectIdentifier(wv))
        logger.log("WebViewPool: created WKWebView network=\(networkConfig.label) (active:\(inUse.count) pool:\(available.count))", category: .webView, level: .trace)
        return wv
    }

    func release(_ webView: WKWebView, wipeData: Bool = true) {
        let id = ObjectIdentifier(webView)
        inUse.remove(id)

        webView.stopLoading()

        if wipeData {
            webView.configuration.websiteDataStore.removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: .distantPast
            ) { }
            webView.configuration.userContentController.removeAllUserScripts()
            HTTPCookieStorage.shared.removeCookies(since: .distantPast)
        }

        if available.count < maxPoolSize {
            available.append(webView)
            logger.log("WebViewPool: returned to pool (active:\(inUse.count) pool:\(available.count))", category: .webView, level: .trace)
        } else {
            webView.navigationDelegate = nil
            logger.log("WebViewPool: discarded (pool full) (active:\(inUse.count) pool:\(available.count))", category: .webView, level: .trace)
        }
    }

    func drainAll() {
        for wv in available {
            wv.stopLoading()
            wv.configuration.websiteDataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { }
            wv.navigationDelegate = nil
        }
        available.removeAll()
        logger.log("WebViewPool: drained all (\(inUse.count) still in use)", category: .webView, level: .info)
    }

    func handleMemoryPressure() {
        let drained = available.count
        drainAll()
        if drained > 0 {
            logger.log("WebViewPool: memory pressure — drained \(drained) idle WebViews", category: .webView, level: .warning)
        }
    }

    func reportProcessTermination() {
        processTerminationCount += 1
        logger.log("WebViewPool: WebKit content process terminated (total: \(processTerminationCount))", category: .webView, level: .error)
        AppAlertManager.shared.pushWarning(
            source: .webView,
            title: "WebView Crash",
            message: "A WebKit content process was terminated. The session will be retried automatically."
        )
    }
}
