import UIKit
import WebKit

/// In-pane overlay for Google OAuth popups — only covers ONE column, not the whole screen.
final class LoginPopupOverlay: UIView, WKNavigationDelegate, WKUIDelegate {
    private let configuration: WKWebViewConfiguration
    private let userAgent: String?
    private var webView: WKWebView!
    var onClose: (() -> Void)?

    init(configuration: WKWebViewConfiguration, userAgent: String?) {
        self.configuration = configuration
        self.userAgent = userAgent
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor(white: 0.1, alpha: 1)
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI() {
        let bar = UIView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.backgroundColor = UIColor(white: 0.18, alpha: 1)
        addSubview(bar)

        let title = UILabel()
        title.text = "本栏登录"
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .label
        title.translatesAutoresizingMaskIntoConstraints = false

        let close = UIButton(type: .system)
        close.setTitle("完成", for: .normal)
        close.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        close.translatesAutoresizingMaskIntoConstraints = false

        bar.addSubview(title)
        bar.addSubview(close)

        let wv = WKWebView(frame: .zero, configuration: configuration)
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.navigationDelegate = self
        wv.uiDelegate = self
        wv.customUserAgent = userAgent
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.minimumZoomScale = 1
        wv.scrollView.maximumZoomScale = 1
        wv.scrollView.pinchGestureRecognizer?.isEnabled = false
        addSubview(wv)
        webView = wv

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: topAnchor),
            bar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 36),

            title.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 10),
            title.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

            close.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -10),
            close.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

            wv.topAnchor.constraint(equalTo: bar.bottomAnchor),
            wv.leadingAnchor.constraint(equalTo: leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func load(_ request: URLRequest) {
        webView.load(request)
    }

    @objc private func closeTapped() {
        removeFromSuperview()
        onClose?()
    }

    func webViewDidClose(_ webView: WKWebView) {
        closeTapped()
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        guard let host = nearestViewController() else {
            completionHandler()
            return
        }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler() })
        host.present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let host = nearestViewController() else {
            completionHandler(false)
            return
        }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler(true) })
        host.present(alert, animated: true)
    }

    private func nearestViewController() -> UIViewController? {
        var r: UIResponder? = self
        while let cur = r {
            if let vc = cur as? UIViewController { return vc }
            r = cur.next
        }
        return nil
    }
}
