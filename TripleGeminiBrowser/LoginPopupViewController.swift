import UIKit
import WebKit

/// Modal browser window for Google OAuth / account picker popups.
/// Shares the parent pane's data store so login cookies land in the correct account slot.
final class LoginPopupViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private let configuration: WKWebViewConfiguration
    private let initialRequest: URLRequest?
    private let userAgent: String?
    private var webView: WKWebView!
    private let onClose: () -> Void

    init(
        configuration: WKWebViewConfiguration,
        request: URLRequest?,
        userAgent: String?,
        onClose: @escaping () -> Void
    ) {
        self.configuration = configuration
        self.initialRequest = request
        self.userAgent = userAgent
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let close = UIButton(type: .system)
        close.setTitle("完成", for: .normal)
        close.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        close.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "Google 登录"
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let bar = UIView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.backgroundColor = UIColor.secondarySystemBackground
        view.addSubview(bar)
        bar.addSubview(title)
        bar.addSubview(close)

        // Must reuse the same websiteDataStore + processPool from parent config.
        let wv = WKWebView(frame: .zero, configuration: configuration)
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.navigationDelegate = self
        wv.uiDelegate = self
        wv.customUserAgent = userAgent
        wv.allowsBackForwardNavigationGestures = true
        view.addSubview(wv)
        webView = wv

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 48),

            title.centerXAnchor.constraint(equalTo: bar.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

            close.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -16),
            close.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

            wv.topAnchor.constraint(equalTo: bar.bottomAnchor),
            wv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        if let initialRequest {
            wv.load(initialRequest)
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onClose()
        }
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
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }
}
