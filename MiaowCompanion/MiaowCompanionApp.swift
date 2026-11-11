import SwiftUI
import WebKit

@main
struct MiaowCompanionApp: App {
    @StateObject private var assets = LocalAssetServer()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            Group {
                if let url = assets.pageURL { CatWebView(url: url, active: scenePhase == .active) }
                else if let error = assets.failure {
                    VStack(spacing: 18) { Text("猫猫还没准备好").font(.title2); Text(error).font(.footnote); Text("请重新打开App；若仍失败，保留提示以便修复。") }.padding(28)
                } else { ProgressView("猫猫正在醒来…") }
            }
            .background(Color(red: 0.97, green: 0.95, blue: 0.91))
        }
    }
}
struct CatWebView: UIViewRepresentable {
    let url: URL
    let active: Bool
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.navigationDelegate = context.coordinator
        context.coordinator.allowedURL = url
        view.load(URLRequest(url: url))
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.active = active
        let state = active ? "true" : "false"
        view.evaluateJavaScript("window.nativePetSetActive?.(\(state));", completionHandler: nil)
    }
    final class Coordinator: NSObject, WKNavigationDelegate {
        var allowedURL: URL?
        var active = true
        func webView(_ view: WKWebView, didFinish navigation: WKNavigation!) {
            view.evaluateJavaScript("window.nativePetSetActive?.(\(active ? "true" : "false"));", completionHandler: nil)
        }
        func webView(_ view: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let candidate = action.request.url, let expected = allowedURL,
                  candidate.scheme == expected.scheme, candidate.host == expected.host, candidate.port == expected.port,
                  candidate.path.hasPrefix(expected.deletingLastPathComponent().path + "/") else { decisionHandler(.cancel); return }
            decisionHandler(.allow)
        }
    }
}
