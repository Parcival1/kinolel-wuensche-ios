// KinoLel Wünsche (iOS): Seerr-Oberfläche (KinoLel Wünsche / KinoLel Kívánságok) mit Umschalter, Wahl wird gemerkt.
import UIKit
import WebKit

final class WunschViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private var web: WKWebView!
    private let umschalter = UISegmentedControl(items: ["Deutsch", "Magyar"])
    private let titel = UILabel()
    private let hinweis = UILabel()
    private var wartenderLink: URL?
    private var startFertig = false   // erste Seite geladen oder ausgefallen → „Was ist neu“, Update-Hinweis

    private var server: URL {
        get {
            if let text = UserDefaults.standard.string(forKey: "server"), let url = URL(string: text) { return url }
            return Marke.ungarisch ? Marke.serverHU : Marke.serverDE
        }
        set { UserDefaults.standard.set(newValue.absoluteString, forKey: "server") }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Marke.grund

        // Leiste: Logo, Name, Umschalter, Neu laden
        let logo = UIImageView(image: UIImage(named: "StartLogo"))
        logo.contentMode = .scaleAspectFit
        titel.textColor = UIColor(white: 1, alpha: 0.9)
        titel.font = Schrift.fett(16)
        titel.adjustsFontSizeToFitWidth = true
        titel.minimumScaleFactor = 0.7
        umschalter.selectedSegmentTintColor = Marke.lavendel
        umschalter.setTitleTextAttributes([.foregroundColor: Marke.grund], for: .selected)
        umschalter.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        umschalter.addTarget(self, action: #selector(gewechselt), for: .valueChanged)
        let neu = UIButton(type: .system)
        neu.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        neu.tintColor = .white
        neu.addTarget(self, action: #selector(neuLaden), for: .touchUpInside)
        let leiste = UIStackView(arrangedSubviews: [logo, titel, umschalter, neu])
        leiste.axis = .horizontal
        leiste.spacing = 10
        leiste.alignment = .center
        leiste.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(leiste)

        let konfig = WKWebViewConfiguration()
        konfig.websiteDataStore = .default()
        konfig.allowsInlineMediaPlayback = true
        let ios = UIDevice.current.systemVersion.split(separator: ".").first ?? "17"
        konfig.applicationNameForUserAgent = "Version/\(ios).0 Mobile/15E148 Safari/604.1 KinoLelWuensche/\(Marke.version)"
        web = WKWebView(frame: .zero, configuration: konfig)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.isOpaque = false
        web.backgroundColor = Marke.grund
        web.scrollView.backgroundColor = Marke.grund
        web.allowsBackForwardNavigationGestures = true
        if #available(iOS 16.4, *) { web.isInspectable = true }
        web.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(web)

        hinweis.textColor = UIColor(white: 1, alpha: 0.8)
        hinweis.numberOfLines = 0
        hinweis.textAlignment = .center
        hinweis.isHidden = true
        hinweis.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hinweis)

        NSLayoutConstraint.activate([
            leiste.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            leiste.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            leiste.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            leiste.heightAnchor.constraint(equalToConstant: 40),
            logo.widthAnchor.constraint(equalToConstant: 32),
            logo.heightAnchor.constraint(equalToConstant: 32),
            web.topAnchor.constraint(equalTo: leiste.bottomAnchor, constant: 4),
            web.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            web.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hinweis.centerYAnchor.constraint(equalTo: web.centerYAnchor),
            hinweis.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            hinweis.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])

        leisteAktualisieren()
        if let link = wartenderLink {
            wartenderLink = nil
            web.load(URLRequest(url: link))
        } else {
            web.load(URLRequest(url: server))
        }
    }

    /// kinolelwuensche://<domain>/<pfad> -> https://<domain>/<pfad>, passenden Server wählen
    func oeffne(schemaUrl: URL) {
        guard var teile = URLComponents(url: schemaUrl, resolvingAgainstBaseURL: false) else { return }
        teile.scheme = "https"
        guard let ziel = teile.url, let passend = serverFuer(ziel) else { return }
        server = passend
        if web == nil {
            wartenderLink = ziel
        } else {
            leisteAktualisieren()
            web.load(URLRequest(url: ziel))
        }
    }

    private func serverFuer(_ url: URL) -> URL? {
        [Marke.serverDE, Marke.serverHU].first { $0.host?.lowercased() == url.host?.lowercased() }
    }

    private func leisteAktualisieren() {
        let hu = server.host == Marke.serverHU.host
        umschalter.selectedSegmentIndex = hu ? 1 : 0
        titel.text = hu ? "KinoLel Kívánságok" : Marke.appName
    }

    @objc private func gewechselt() {
        server = umschalter.selectedSegmentIndex == 1 ? Marke.serverHU : Marke.serverDE
        leisteAktualisieren()
        web.load(URLRequest(url: server))
    }

    @objc private func neuLaden() {
        hinweis.isHidden = true
        if web.url == nil { web.load(URLRequest(url: server)) } else { web.reload() }
    }

    // MARK: Navigation

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return decisionHandler(.allow) }
        if let passend = serverFuer(url) {
            if passend != server {
                server = passend
                leisteAktualisieren()
            }
            return decisionHandler(.allow)
        }
        if ["about", "blob", "data"].contains(url.scheme ?? "") { return decisionHandler(.allow) }
        if navigationAction.targetFrame?.isMainFrame ?? true {
            // fremde Seiten (Jellyfin, TMDB, Trailer …) in Safari bzw. der passenden App öffnen
            UIApplication.shared.open(url)
            return decisionHandler(.cancel)
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            if serverFuer(url) != nil { webView.load(URLRequest(url: url)) } else { UIApplication.shared.open(url) }
        }
        return nil
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        hinweis.isHidden = true
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
        hinweis.text = T("Die Wunschseite ist gerade nicht erreichbar.\nBitte Internetverbindung prüfen und oben ↻ tippen.",
                         "A kívánságoldal most nem érhető el.\nKérjük, ellenőrizd az internetkapcsolatot, majd koppints a ↻ gombra.",
                         "The wish page cannot be reached right now.\nPlease check your internet connection and tap ↻ at the top.")
        hinweis.isHidden = false
        startAbgeschlossen()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        startAbgeschlossen()
    }

    // MARK: Nach dem Start: „Was ist neu“, dann Update-Hinweis

    private func startAbgeschlossen() {
        guard !startFertig else { return }
        startFertig = true
        meldungenZeigen()
    }

    private func meldungenZeigen() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self else { return }
            guard self.presentedViewController == nil else { return self.meldungenZeigen() }
            Neuigkeiten.zeigen(auf: self) { [weak self] in
                guard let self else { return }
                Aktualisierung.pruefen(auf: self)
            }
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}
