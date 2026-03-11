import Foundation
import WebKit

@MainActor
class WebViewPool {
    static let shared = WebViewPool()

    private var inUse: Set<ObjectIdentifier> = []
    private let logger = DebugLogger.shared
    private(set) var processTerminationCount: Int = 0

    var activeCount: Int { inUse.count }

    func acquire(stealthEnabled: Bool = false, viewportSize: CGSize = CGSize(width: 390, height: 844), networkConfig: ActiveNetworkConfig = .direct, target: ProxyRotationService.ProxyTarget = .joe) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        NetworkSessionFactory.shared.configureWKWebView(config: config, networkConfig: networkConfig, target: target)

        if stealthEnabled {
            let stealth = PPSRStealthService.shared
            let profile = stealth.nextProfile()
            let userScript = stealth.createStealthUserScript(profile: profile)
            config.userContentController.addUserScript(userScript)

            let wv = WKWebView(frame: CGRect(origin: .zero, size: CGSize(width: profile.viewport.width, height: profile.viewport.height)), configuration: config)
            wv.customUserAgent = profile.userAgent
            inUse.insert(ObjectIdentifier(wv))
            logger.log("WebViewPool: acquired stealth WKWebView network=\(networkConfig.label) (active:\(inUse.count))", category: .webView, level: .trace)
            return wv
        }

        let wv = WKWebView(frame: CGRect(origin: .zero, size: viewportSize), configuration: config)
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        inUse.insert(ObjectIdentifier(wv))
        logger.log("WebViewPool: created WKWebView network=\(networkConfig.label) (active:\(inUse.count))", category: .webView, level: .trace)
        return wv
    }

    func release(_ webView: WKWebView, wipeData: Bool = true) {
        let id = ObjectIdentifier(webView)
        inUse.remove(id)

        webView.stopLoading()

        if wipeData {
            let dataStore = webView.configuration.websiteDataStore
            dataStore.proxyConfigurations = []
            dataStore.removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: .distantPast
            ) { }
            webView.configuration.userContentController.removeAllUserScripts()
            HTTPCookieStorage.shared.removeCookies(since: .distantPast)
        }

        webView.navigationDelegate = nil
        logger.log("WebViewPool: released (active:\(inUse.count))", category: .webView, level: .trace)
    }

    func handleMemoryPressure() {
        logger.log("WebViewPool: memory pressure noted (\(inUse.count) active)", category: .webView, level: .warning)
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
