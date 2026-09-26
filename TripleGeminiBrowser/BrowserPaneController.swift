import UIKit
import WebKit

enum PaneID: Int, CaseIterable {
    case left = 0
    case center = 1
    case right = 2

    var title: String {
        switch self {
        case .left: return "左"
        case .center: return "中"
        case .right: return "右"
        }
    }

    var storageKey: String { "pane-\(rawValue)" }
}

enum BrowserDefaults {
    static let homeURL = URL(string: "https://gemini.google.com/app")!
    static let desktopUA =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
}

final class BrowserPaneController: UIViewController, WKNavigationDelegate, WKUIDelegate, UITextFieldDelegate {
    let paneID: PaneID

    private var webView: WKWebView!
    private let topBar = UIView()
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let backButton = UIButton(type: .system)
    private let forwardButton = UIButton(type: .system)
    private let reloadButton = UIButton(type: .system)
    private let homeButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    private let desktopButton = UIButton(type: .system)
    private let urlField = UITextField()
    private let titleLabel = UILabel()

    private var progressObservation: NSKeyValueObservation?
    private var desktopMode = true
    private var cookieSaveWorkItem: DispatchWorkItem?

    init(paneID: PaneID) {
        self.paneID = paneID
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.12, alpha: 1)
        buildChrome()
        buildWebView()
        loadInitialURL()
    }

    deinit {
        progressObservation?.invalidate()
    }

    // MARK: - UI

    private func buildChrome() {
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = UIColor(white: 0.16, alpha: 1)
        view.addSubview(topBar)

        titleLabel.text = paneID.title
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        configureNavButton(backButton, systemName: "chevron.left", action: #selector(goBack))
        configureNavButton(forwardButton, systemName: "chevron.right", action: #selector(goForward))
        configureNavButton(reloadButton, systemName: "arrow.clockwise", action: #selector(reloadOrStop))
        configureNavButton(homeButton, systemName: "house", action: #selector(goHome))
        configureNavButton(clearButton, systemName: "person.crop.circle.badge.minus", action: #selector(clearLogin))
        configureNavButton(desktopButton, systemName: "desktopcomputer", action: #selector(toggleDesktop))

        urlField.translatesAutoresizingMaskIntoConstraints = false
        urlField.borderStyle = .roundedRect
        urlField.font = .systemFont(ofSize: 13)
        urlField.autocapitalizationType = .none
        urlField.autocorrectionType = .no
        urlField.keyboardType = .URL
        urlField.returnKeyType = .go
        urlField.clearButtonMode = .whileEditing
        urlField.delegate = self
        urlField.placeholder = "网址或搜索"
        urlField.textContentType = .URL

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = .clear
        progressView.isHidden = true

        let navStack = UIStackView(arrangedSubviews: [
            backButton, forwardButton, reloadButton, homeButton, desktopButton, clearButton
        ])
        navStack.axis = .horizontal
        navStack.spacing = 2
        navStack.translatesAutoresizingMaskIntoConstraints = false

        topBar.addSubview(titleLabel)
        topBar.addSubview(navStack)
        topBar.addSubview(urlField)
        topBar.addSubview(progressView)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: navStack.centerYAnchor),
            titleLabel.widthAnchor.constraint(equalToConstant: 18),

            navStack.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 4),
            navStack.topAnchor.constraint(equalTo: topBar.topAnchor, constant: 6),
            navStack.heightAnchor.constraint(equalToConstant: 32),

            urlField.leadingAnchor.constraint(equalTo: navStack.trailingAnchor, constant: 6),
            urlField.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -8),
            urlField.centerYAnchor.constraint(equalTo: navStack.centerYAnchor),
            urlField.heightAnchor.constraint(equalToConstant: 30),

            progressView.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            progressView.bottomAnchor.constraint(equalTo: topBar.bottomAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),

            topBar.bottomAnchor.constraint(equalTo: navStack.bottomAnchor, constant: 8),
        ])
    }

    private func configureNavButton(_ button: UIButton, systemName: String, action: Selector) {
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        button.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        button.tintColor = .label
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func buildWebView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = Self.makeDataStore(for: paneID)
        config.processPool = WKProcessPool()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        if #available(iOS 15.0, *) {
            config.preferences.isElementFullscreenEnabled = true
        }

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.navigationDelegate = self
        wv.uiDelegate = self
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        if desktopMode {
            wv.customUserAgent = BrowserDefaults.desktopUA
        }
        view.addSubview(wv)

        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            wv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        webView = wv
        progressObservation = wv.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            self?.updateProgress(webView.estimatedProgress)
        }

        restoreCookiesIfNeeded()
    }

    private static func makeDataStore(for pane: PaneID) -> WKWebsiteDataStore {
        if #available(iOS 17.0, *) {
            // Stable UUID per pane so logins survive relaunches.
            let defaults = UserDefaults.standard
            let key = "dataStoreID-\(pane.storageKey)"
            let uuid: UUID
            if let raw = defaults.string(forKey: key), let parsed = UUID(uuidString: raw) {
                uuid = parsed
            } else {
                uuid = UUID()
                defaults.set(uuid.uuidString, forKey: key)
            }
            return WKWebsiteDataStore(forIdentifier: uuid)
        }
        // iOS 15/16: non-persistent store + cookie files (see restore/save).
        return .nonPersistent()
    }

    // MARK: - Navigation actions

    private func loadInitialURL() {
        let key = "lastURL-\(paneID.storageKey)"
        if let saved = UserDefaults.standard.string(forKey: key), let url = URL(string: saved) {
            webView.load(URLRequest(url: url))
        } else {
            webView.load(URLRequest(url: BrowserDefaults.homeURL))
        }
    }

    @objc private func goBack() { if webView.canGoBack { webView.goBack() } }
    @objc private func goForward() { if webView.canGoForward { webView.goForward() } }

    @objc private func reloadOrStop() {
        if webView.isLoading {
            webView.stopLoading()
        } else {
            webView.reload()
        }
    }

    @objc private func goHome() {
        webView.load(URLRequest(url: BrowserDefaults.homeURL))
    }

    @objc private func toggleDesktop() {
        desktopMode.toggle()
        webView.customUserAgent = desktopMode ? BrowserDefaults.desktopUA : nil
        desktopButton.tintColor = desktopMode ? .systemBlue : .label
        webView.reload()
    }

    @objc private func clearLogin() {
        let store = webView.configuration.websiteDataStore
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        store.fetchDataRecords(ofTypes: types) { records in
            store.removeData(ofTypes: types, for: records) { [weak self] in
                self?.deleteCookieFile()
                DispatchQueue.main.async {
                    self?.webView.load(URLRequest(url: BrowserDefaults.homeURL))
                }
            }
        }
    }

    private func updateProgress(_ value: Double) {
        progressView.isHidden = value <= 0 || value >= 1
        progressView.setProgress(Float(value), animated: true)
        if value >= 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.progressView.isHidden = true
                self?.progressView.progress = 0
            }
        }
    }

    private func updateURLBar() {
        urlField.text = webView.url?.absoluteString
        backButton.isEnabled = webView.canGoBack
        forwardButton.isEnabled = webView.canGoForward
        if let url = webView.url?.absoluteString {
            UserDefaults.standard.set(url, forKey: "lastURL-\(paneID.storageKey)")
        }
    }

    // MARK: - URL helpers

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        guard let raw = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return true
        }
        webView.load(URLRequest(url: Self.resolveURL(from: raw)))
        return true
    }

    static func resolveURL(from input: String) -> URL {
        if input.hasPrefix("http://") || input.hasPrefix("https://"), let url = URL(string: input) {
            return url
        }
        if input.contains(".") && !input.contains(" "),
           let url = URL(string: "https://\(input)") {
            return url
        }
        let encoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
        return URL(string: "https://www.google.com/search?q=\(encoded)")!
    }

    // MARK: - Cookie persistence (iOS 15/16)

    private var cookieFileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("cookies-\(paneID.storageKey).json")
    }

    private func deleteCookieFile() {
        try? FileManager.default.removeItem(at: cookieFileURL)
    }

    private func restoreCookiesIfNeeded() {
        if #available(iOS 17.0, *) { return }
        guard let data = try? Data(contentsOf: cookieFileURL),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
        let store = webView.configuration.websiteDataStore.httpCookieStore
        for dict in array {
            if let cookie = HTTPCookie(properties: Self.cookieProperties(from: dict)) {
                store.setCookie(cookie)
            }
        }
    }

    private func scheduleSaveCookies() {
        if #available(iOS 17.0, *) { return }
        cookieSaveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveCookies() }
        cookieSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    private func saveCookies() {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }
            let payload: [[String: Any]] = cookies.compactMap { cookie in
                guard let props = cookie.properties else { return nil }
                var out: [String: Any] = [:]
                for (key, value) in props {
                    out[key.rawValue] = "\(value)"
                }
                return out
            }
            if let data = try? JSONSerialization.data(withJSONObject: payload, options: []) {
                try? data.write(to: self.cookieFileURL, options: .atomic)
            }
        }
    }

    private static func cookieProperties(from dict: [String: Any]) -> [HTTPCookiePropertyKey: Any] {
        var props: [HTTPCookiePropertyKey: Any] = [:]
        for (key, value) in dict {
            props[HTTPCookiePropertyKey(key)] = value
        }
        return props
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        updateURLBar()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateURLBar()
        scheduleSaveCookies()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        updateURLBar()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url,
           ["tel", "mailto", "sms"].contains(url.scheme?.lowercased() ?? "") {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    // MARK: - WKUIDelegate (Google login popups)

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: paneID.title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(title: paneID.title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }
}
