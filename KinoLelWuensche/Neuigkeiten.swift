// KinoLel Wünsche (iOS): Sprache der App (de/hu/en), einmalige Meldung „Neu in …“ nach einem Update (Lel 22.10.2026)
// und Hinweis auf neue Versionen – wie in der KinoLel-App und der Android-App. Texte: neuigkeiten.json.
// Neuinstallation: keine Meldung. Erstes Update auf eine Version mit dieser Meldung: die zwei neuesten Einträge.
import UIKit

enum Sprache: String {
    case de, hu, en

    /// Erste passende Gerätesprache – sonst Deutsch
    static var aktuell: Sprache {
        for kennung in Locale.preferredLanguages {
            if let sprache = Sprache(rawValue: String(kennung.prefix(2)).lowercased()) { return sprache }
        }
        return .de
    }
}

/// Text in der aktuellen Sprache
func T(_ de: String, _ hu: String, _ en: String) -> String {
    switch Sprache.aktuell {
    case .de: return de
    case .hu: return hu
    case .en: return en
    }
}

enum Versionsnummer {
    /// „v0.1.1“ / „0.1.1-test“ → [0, 1, 1]
    static func teile(_ text: String) -> [Int] {
        var t = text.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("v") { t.removeFirst() }
        let kern = t.split(separator: "-", maxSplits: 1).first.map(String.init) ?? t
        return kern.split(separator: ".").map { Int($0) ?? 0 }
    }

    static func vergleiche(_ a: [Int], _ b: [Int]) -> Int {
        for i in 0..<max(a.count, b.count) {
            let unterschied = (i < a.count ? a[i] : 0) - (i < b.count ? b[i] : 0)
            if unterschied != 0 { return unterschied }
        }
        return 0
    }

    static func text(_ teile: [Int]) -> String { teile.map(String.init).joined(separator: ".") }
}

enum Neuigkeiten {
    struct Eintrag { let version: String; let punkte: [String] }

    private static let gesehenSchluessel = "kinolel.neuigkeitenGesehen"
    private static let ohneVorgaenger = 2
    private(set) static var offen: [Eintrag] = []

    /// Name in der App-Sprache (ungarisch: KinoLel Kívánságok)
    static var appName: String { Sprache.aktuell == .hu ? "KinoLel Kívánságok" : Marke.appName }

    /// Beim App-Start (vor dem ersten WKWebView): offene Einträge ermitteln, aktuelle Version als gesehen merken
    static func vorbereiten() {
        let vorlieben = UserDefaults.standard
        let aktuell = Versionsnummer.teile(Marke.version)
        var gesehenText = vorlieben.string(forKey: gesehenSchluessel)
        #if DEBUG
        // Test im Simulator: so tun, als käme das Update von dieser Version (-KinoLelTestNeuigkeitenSeit 0.1.0)
        if let test = vorlieben.string(forKey: "KinoLelTestNeuigkeitenSeit") { gesehenText = test }
        #endif
        if let gesehenText, Versionsnummer.vergleiche(Versionsnummer.teile(gesehenText), aktuell) >= 0 { return }
        let aktualisiert = gesehenText != nil || frueherGenutzt()
        vorlieben.set(Versionsnummer.text(aktuell), forKey: gesehenSchluessel)
        guard aktualisiert else { return }

        guard let url = Bundle.main.url(forResource: "neuigkeiten", withExtension: "json"),
              let daten = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: daten) as? [String: Any],
              let versionen = json["versionen"] as? [[String: Any]] else { return }
        let sprache = Sprache.aktuell.rawValue
        let gesehen = gesehenText.map(Versionsnummer.teile)
        var liste: [(teile: [Int], eintrag: Eintrag)] = []
        for v in versionen {
            guard let text = v["version"] as? String else { continue }
            let teile = Versionsnummer.teile(text)
            guard Versionsnummer.vergleiche(teile, aktuell) <= 0 else { continue }
            if let gesehen, Versionsnummer.vergleiche(teile, gesehen) <= 0 { continue }
            let punkte = (v[sprache] as? [String]) ?? (v["de"] as? [String]) ?? []
            if !punkte.isEmpty { liste.append((teile, Eintrag(version: text, punkte: punkte))) }
        }
        liste.sort { Versionsnummer.vergleiche($0.teile, $1.teile) > 0 }
        offen = (gesehen == nil ? Array(liste.prefix(ohneVorgaenger)) : liste).map(\.eintrag)
        NSLog("KinoLel Wünsche: Was ist neu – %ld Einträge", offen.count)
    }

    /// Gab es die App schon vorher? Ältere Versionen haben nichts gespeichert, aber die Wunschseite lief schon
    /// (Daten des WKWebView unter Library/WebKit bzw. Cookies).
    private static func frueherGenutzt() -> Bool {
        let bibliothek = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return ["WebKit", "Cookies"].contains {
            FileManager.default.fileExists(atPath: bibliothek.appendingPathComponent($0).path)
        }
    }

    static func zeigen(auf gastgeber: UIViewController, fertig: @escaping () -> Void) {
        guard !offen.isEmpty else { return fertig() }
        let ansicht = NeuigkeitenViewController(eintraege: offen, fertig: fertig)
        offen = []
        gastgeber.present(ansicht, animated: true)
    }
}

final class NeuigkeitenViewController: UIViewController {
    private let eintraege: [Neuigkeiten.Eintrag]
    private let fertig: () -> Void

    init(eintraege: [Neuigkeiten.Eintrag], fertig: @escaping () -> Void) {
        self.eintraege = eintraege
        self.fertig = fertig
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let blatt = sheetPresentationController {
            blatt.detents = [.medium(), .large()]
            blatt.prefersGrabberVisible = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) nicht unterstützt") }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = Marke.grund

        let ueberschrift = UILabel()
        let name = Neuigkeiten.appName, version = Marke.version
        ueberschrift.text = T("Neu in \(name) \(version)", "Újdonságok – \(name) \(version)", "New in \(name) \(version)")
        ueberschrift.font = .preferredFont(forTextStyle: .title2).fett
        ueberschrift.textColor = Marke.lavendel
        ueberschrift.numberOfLines = 0
        ueberschrift.accessibilityIdentifier = "kinolel.neuigkeiten.titel"

        let text = UITextView()
        text.isEditable = false
        text.backgroundColor = .clear
        text.textContainerInset = .zero
        text.textContainer.lineFragmentPadding = 0
        text.attributedText = inhalt()

        let knopf = UIButton(type: .system)
        knopf.setTitle(T("Alles klar", "Rendben", "Got it"), for: .normal)
        knopf.setTitleColor(Marke.grund, for: .normal)
        knopf.titleLabel?.font = .boldSystemFont(ofSize: 17)
        knopf.backgroundColor = Marke.lavendel
        knopf.layer.cornerRadius = 10
        knopf.accessibilityIdentifier = "kinolel.neuigkeiten.ok"
        knopf.addTarget(self, action: #selector(schliessen), for: .touchUpInside)

        for v in [ueberschrift, text, knopf] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        let rand = view.layoutMarginsGuide
        NSLayoutConstraint.activate([
            ueberschrift.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28),
            ueberschrift.leadingAnchor.constraint(equalTo: rand.leadingAnchor, constant: 8),
            ueberschrift.trailingAnchor.constraint(equalTo: rand.trailingAnchor, constant: -8),
            text.topAnchor.constraint(equalTo: ueberschrift.bottomAnchor, constant: 16),
            text.leadingAnchor.constraint(equalTo: ueberschrift.leadingAnchor),
            text.trailingAnchor.constraint(equalTo: ueberschrift.trailingAnchor),
            text.bottomAnchor.constraint(equalTo: knopf.topAnchor, constant: -16),
            knopf.leadingAnchor.constraint(equalTo: ueberschrift.leadingAnchor),
            knopf.trailingAnchor.constraint(equalTo: ueberschrift.trailingAnchor),
            knopf.heightAnchor.constraint(equalToConstant: 50),
            knopf.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    /// Versionen fett (nur bei mehreren), Punkte mit hängendem Einzug
    private func inhalt() -> NSAttributedString {
        let ergebnis = NSMutableAttributedString()
        let normal = UIFont.preferredFont(forTextStyle: .body)
        let punkt = NSMutableParagraphStyle()
        punkt.headIndent = 18
        punkt.tabStops = [NSTextTab(textAlignment: .left, location: 18)]
        punkt.paragraphSpacing = 8
        let kopf = NSMutableParagraphStyle()
        kopf.paragraphSpacingBefore = 6
        kopf.paragraphSpacing = 6
        for (i, eintrag) in eintraege.enumerated() {
            if eintraege.count > 1 {
                let titel = T("Version \(eintrag.version)", "\(eintrag.version). verzió", "Version \(eintrag.version)")
                ergebnis.append(NSAttributedString(string: (i > 0 ? "\n" : "") + titel + "\n", attributes: [
                    .font: normal.fett, .foregroundColor: UIColor.white.withAlphaComponent(0.85), .paragraphStyle: kopf
                ]))
            }
            for p in eintrag.punkte {
                ergebnis.append(NSAttributedString(string: "•\t" + p + "\n", attributes: [
                    .font: normal, .foregroundColor: UIColor.white, .paragraphStyle: punkt
                ]))
            }
        }
        return ergebnis
    }

    @objc private func schliessen() { dismiss(animated: true) }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil { fertig() }
    }
}

/// Hinweis auf eine neue Version (GitHub-Releases, höchstens alle 6 Stunden). Installiert wird über SideStore
/// (Quelle https://kinolel.de/web/kinolel/sidestore.json) – „Aktualisieren“ öffnet SideStore.
enum Aktualisierung {
    private static let repo = "Parcival1/kinolel-wuensche-ios"
    private static let abstand: TimeInterval = 6 * 60 * 60
    private static let zuletztSchluessel = "kinolel.updateZuletzt"

    static func pruefen(auf gastgeber: UIViewController) {
        let jetzt = Date().timeIntervalSince1970
        guard jetzt - UserDefaults.standard.double(forKey: zuletztSchluessel) >= abstand,
              let url = URL(string: "https://api.github.com/repos/\(repo)/releases?per_page=10") else { return }
        UserDefaults.standard.set(jetzt, forKey: zuletztSchluessel)
        var anfrage = URLRequest(url: url, timeoutInterval: 15)
        anfrage.setValue("KinoLelWuensche-iOS/\(Marke.version)", forHTTPHeaderField: "User-Agent")
        anfrage.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: anfrage) { [weak gastgeber] daten, _, _ in
            guard let daten, let releases = (try? JSONSerialization.jsonObject(with: daten)) as? [[String: Any]] else { return }
            var beste = Versionsnummer.teile(Marke.version)
            var seite: URL?
            for release in releases where (release["draft"] as? Bool) != true {
                let version = Versionsnummer.teile(release["tag_name"] as? String ?? "")
                let anhaenge = release["assets"] as? [[String: Any]] ?? []
                guard Versionsnummer.vergleiche(version, beste) > 0,
                      anhaenge.contains(where: { ($0["name"] as? String ?? "").hasSuffix(".ipa") }),
                      let adresse = (release["html_url"] as? String).flatMap({ URL(string: $0) }) else { continue }
                beste = version
                seite = adresse
            }
            guard let seite else { return }
            DispatchQueue.main.async {
                guard let gastgeber, gastgeber.view.window != nil, gastgeber.presentedViewController == nil else {
                    UserDefaults.standard.removeObject(forKey: zuletztSchluessel)
                    return
                }
                let name = Neuigkeiten.appName, version = Versionsnummer.text(beste)
                let hinweis = UIAlertController(
                    title: T("Update verfügbar", "Frissítés elérhető", "Update available"),
                    message: T("\(name) \(version) ist verfügbar.\n„Aktualisieren“ öffnet SideStore: dort unter „My Apps“ bei \(name) auf „Update“ tippen.",
                               "Elérhető a(z) \(name) \(version).\nA „Frissítés” megnyitja a SideStore-t: ott a „My Apps” alatt koppints a(z) \(name) melletti „Update” gombra.",
                               "\(name) \(version) is available.\n“Update” opens SideStore: tap “Update” next to \(name) under “My Apps”."),
                    preferredStyle: .alert)
                hinweis.addAction(UIAlertAction(title: T("Später", "Később", "Later"), style: .cancel))
                hinweis.addAction(UIAlertAction(title: T("Aktualisieren", "Frissítés", "Update"), style: .default) { _ in
                    oeffne(["sidestore://", "altstore://"], sonst: seite)
                })
                gastgeber.present(hinweis, animated: true)
            }
        }.resume()
    }

    /// Erste App öffnen, die sich meldet (SideStore, AltStore) – sonst die Download-Seite
    private static func oeffne(_ adressen: [String], sonst seite: URL) {
        guard let erste = adressen.first, let url = URL(string: erste) else { return UIApplication.shared.open(seite) }
        UIApplication.shared.open(url) { geoeffnet in
            if !geoeffnet { oeffne(Array(adressen.dropFirst()), sonst: seite) }
        }
    }
}

private extension UIFont {
    var fett: UIFont {
        guard let beschreibung = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: beschreibung, size: 0)
    }
}
