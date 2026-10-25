// KinoLel Wünsche (iOS): Sprache der App (de/hu/en), einmalige Meldung „Neu in …“ nach einem Update (Lel 22.10.2026)
// und Hinweis auf neue Versionen – wie in der KinoLel-App und der Android-App. Texte: neuigkeiten.json.
// Neuinstallation: keine Meldung. Erstes Update auf eine Version mit dieser Meldung: die zwei neuesten Einträge.
import UIKit
import WebKit

enum Sprache: String {
    case de, hu, en

    /// Erste passende Gerätesprache – sonst Deutsch
    static var geraet: Sprache {
        for kennung in Locale.preferredLanguages {
            if let sprache = Sprache(rawValue: String(kennung.prefix(2)).lowercased()) { return sprache }
        }
        return .de
    }

    /// Lel 25.10. („Sind Updatenachrichten auch auf Ungarisch … wenn die ausgewählte Sprache auf Ungarisch ist?“):
    /// Texte der App in der Sprache der Wunschseite – die im Seerr-Konto gewählte Anzeigesprache, sonst die des Servers
    /// (KinoLel Wünsche: Deutsch, KinoLel Kívánságok: Ungarisch). Je Server gemerkt; noch unbekannt: Gerätesprache.
    static var aktuell: Sprache {
        UserDefaults.standard.string(forKey: schluessel(gewaehlterServer)).flatMap(Sprache.init(rawValue:)) ?? geraet
    }

    /// Server laut Umschalter (gemerkt im WunschViewController), sonst nach Gerätesprache
    private static var gewaehlterServer: String {
        UserDefaults.standard.string(forKey: "server").flatMap { URL(string: $0)?.host }
            ?? (geraet == .hu ? Marke.serverHU : Marke.serverDE).host ?? ""
    }

    private static func schluessel(_ host: String) -> String { "kinolel.sprache.\(host)" }

    /// Sprache der Seite lesen (im WKWebView, gleiche Herkunft, mit der Anmeldung der Seite) und für ihren Server merken
    static func lesen(aus web: WKWebView, fertig: @escaping () -> Void) {
        guard let host = web.url?.host, [Marke.serverDE.host, Marke.serverHU.host].contains(host) else { return fertig() }
        // Abgemeldet (Anmeldeseite): /auth/me nicht anfragen, nur die Standardsprache des Servers
        let js = """
        let l = '';
        try { l = (await (await fetch('/api/v1/settings/public')).json()).locale || ''; } catch (e) {}
        if (!location.pathname.startsWith('/login')) {
          try {
            const r = await fetch('/api/v1/auth/me');
            if (r.ok) {
              const u = await r.json();
              let eigene = u.settings ? u.settings.locale : undefined;
              if (eigene === undefined) {
                const m = await fetch('/api/v1/user/' + u.id + '/settings/main');
                if (m.ok) eigene = (await m.json()).locale;
              }
              if (eigene) l = eigene;
            }
          } catch (e) {}
        }
        return l;
        """
        web.callAsyncJavaScript(js, arguments: [:], in: nil, in: .page) { ergebnis in
            if case .success(let wert) = ergebnis, let text = wert as? String,
               let sprache = Sprache(rawValue: String(text.prefix(2)).lowercased()) {
                UserDefaults.standard.set(sprache.rawValue, forKey: schluessel(host))
                NSLog("KinoLel Wünsche: Sprache der Wunschseite %@ (%@)", sprache.rawValue, host)
            }
            fertig()
        }
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
    struct Eintrag { let version: String; let texte: [String: Any] }

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
        let gesehen = gesehenText.map(Versionsnummer.teile)
        var liste: [(teile: [Int], eintrag: Eintrag)] = []
        for v in versionen {
            guard let text = v["version"] as? String else { continue }
            let teile = Versionsnummer.teile(text)
            guard Versionsnummer.vergleiche(teile, aktuell) <= 0 else { continue }
            if let gesehen, Versionsnummer.vergleiche(teile, gesehen) <= 0 { continue }
            liste.append((teile, Eintrag(version: text, texte: v)))
        }
        liste.sort { Versionsnummer.vergleiche($0.teile, $1.teile) > 0 }
        offen = (gesehen == nil ? Array(liste.prefix(ohneVorgaenger)) : liste).map(\.eintrag)
        NSLog("KinoLel Wünsche: Was ist neu – %ld Einträge", offen.count)
    }

    /// Stichpunkte in der aktuellen Sprache (Ersatz: Deutsch) – erst beim Zeigen, wenn die Sprache der Seite bekannt ist
    private static func punkte(_ eintrag: Eintrag) -> [String] {
        (eintrag.texte[Sprache.aktuell.rawValue] as? [String]) ?? (eintrag.texte["de"] as? [String]) ?? []
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
        let name = appName, version = Marke.version
        let titel = T("Neu in \(name) \(version)", "Újdonságok – \(name) \(version)", "New in \(name) \(version)")
        NSLog("KinoLel Wünsche: Was ist neu gezeigt – Sprache %@, Titel %@", Sprache.aktuell.rawValue, titel)
        let dialog = KinoLelDialog(
            titel: titel,
            attributiert: inhalt(offen),
            knoepfe: [KinoLelDialog.Knopf(titel: T("Alles klar", "Rendben", "Got it"), art: .haupt, kennung: "kinolel.neuigkeiten.ok")],
            titelKennung: "kinolel.neuigkeiten.titel")
        dialog.beimSchliessen = fertig
        offen = []
        dialog.zeigen(auf: gastgeber)
    }

    /// Versionen fett (nur bei mehreren), Punkte mit hängendem Einzug
    private static func inhalt(_ eintraege: [Eintrag]) -> NSAttributedString {
        let ergebnis = NSMutableAttributedString()
        let punkt = NSMutableParagraphStyle()
        punkt.headIndent = 18
        punkt.tabStops = [NSTextTab(textAlignment: .left, location: 18)]
        punkt.paragraphSpacing = 8
        punkt.lineSpacing = 2
        let kopf = NSMutableParagraphStyle()
        kopf.paragraphSpacingBefore = 6
        kopf.paragraphSpacing = 6
        for (i, eintrag) in eintraege.enumerated() {
            if eintraege.count > 1 {
                let titel = T("Version \(eintrag.version)", "\(eintrag.version). verzió", "Version \(eintrag.version)")
                ergebnis.append(NSAttributedString(string: (i > 0 ? "\n" : "") + titel + "\n", attributes: [
                    .font: Schrift.fett(16), .foregroundColor: UIColor.white, .paragraphStyle: kopf
                ]))
            }
            for p in punkte(eintrag) {
                ergebnis.append(NSAttributedString(string: "•\t" + p + "\n", attributes: [
                    .font: Schrift.normal(16), .foregroundColor: UIColor(white: 0.88, alpha: 1), .paragraphStyle: punkt
                ]))
            }
        }
        return ergebnis
    }
}

/// Hinweis auf eine neue Version (Lel 22.10.2026: bei jedem Öffnen und Zurückkehren, höchstens einmal pro Minute;
/// „Später“ gilt 4 Stunden). Versionsliste auf kinolel.de, GitHub nur als Rückfall. Installiert wird über SideStore
/// (Quelle https://kinolel.de/web/kinolel/sidestore.json) – „Aktualisieren“ öffnet SideStore.
enum Aktualisierung {
    private static let repo = "Parcival1/kinolel-wuensche-ios"
    private static let listenSchluessel = "wuensche-ios"
    private static let minAbstand: TimeInterval = 60
    private static let spaeterDauer: TimeInterval = 4 * 60 * 60
    private static let zuletztSchluessel = "kinolel.updateZuletzt"
    private static let spaeterVersionSchluessel = "kinolel.updateSpaeterVersion"
    private static let spaeterZeitSchluessel = "kinolel.updateSpaeterZeit"
    private static var zeigt = false

    static func pruefen(auf gastgeber: UIViewController) {
        let jetzt = Date().timeIntervalSince1970
        guard !zeigt, jetzt - UserDefaults.standard.double(forKey: zuletztSchluessel) >= minAbstand else { return }
        UserDefaults.standard.set(jetzt, forKey: zuletztSchluessel)
        suchen { neu in
            DispatchQueue.main.async { [weak gastgeber] in
                guard let neu, let gastgeber else { return }
                zeigen(neu.version, neu.seite, auf: gastgeber)
            }
        }
    }

    private static func zeigen(_ version: [Int], _ seite: URL, auf gastgeber: UIViewController) {
        let text = Versionsnummer.text(version)
        let vorlieben = UserDefaults.standard
        if vorlieben.string(forKey: spaeterVersionSchluessel) == text,
           Date().timeIntervalSince1970 - vorlieben.double(forKey: spaeterZeitSchluessel) < spaeterDauer { return }
        // Nicht über den Player oder andere Fenster legen – beim nächsten Öffnen erneut
        guard !zeigt, gastgeber.view.window != nil, gastgeber.presentedViewController == nil else {
            vorlieben.removeObject(forKey: zuletztSchluessel)
            return
        }
        zeigt = true
        let name = Neuigkeiten.appName
        let dialog = KinoLelDialog(
            titel: T("Update verfügbar", "Frissítés elérhető", "Update available"),
            text: T("\(name) \(text) ist verfügbar.\n„Aktualisieren“ öffnet SideStore: dort unter „My Apps“ bei \(name) auf „Update“ tippen.",
                    "Elérhető a(z) \(name) \(text).\nA „Frissítés” megnyitja a SideStore-t: ott a „My Apps” alatt koppints a(z) \(name) melletti „Update” gombra.",
                    "\(name) \(text) is available.\n“Update” opens SideStore: tap “Update” next to \(name) under “My Apps”."),
            knoepfe: [
            KinoLelDialog.Knopf(titel: T("Später", "Később", "Later")) {
                vorlieben.set(text, forKey: spaeterVersionSchluessel)
                vorlieben.set(Date().timeIntervalSince1970, forKey: spaeterZeitSchluessel)
            },
            KinoLelDialog.Knopf(titel: T("Aktualisieren", "Frissítés", "Update"), art: .haupt, kennung: "kinolel.update.jetzt") {
                oeffne(["sidestore://", "altstore://"], sonst: seite)
            }
        ])
        dialog.beimSchliessen = { zeigt = false }
        dialog.zeigen(auf: gastgeber)
    }

    /// Neuere Version (oder nil): erst die Versionsliste auf kinolel.de, sonst GitHub
    private static func suchen(_ fertig: @escaping ((version: [Int], seite: URL)?) -> Void) {
        let aktuell = Versionsnummer.teile(Marke.version)
        let liste = URL(string: "https://kinolel.de/web/kinolel/apps.json")!
        var anfrage = URLRequest(url: liste, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        anfrage.setValue("KinoLelWuensche-iOS/\(Marke.version)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: anfrage) { daten, antwort, _ in
            guard (antwort as? HTTPURLResponse)?.statusCode == 200, let daten,
                  let json = (try? JSONSerialization.jsonObject(with: daten)) as? [String: Any],
                  let eintrag = json[listenSchluessel] as? [String: Any],
                  let versionText = eintrag["version"] as? String,
                  let seite = (eintrag["seite"] as? String).flatMap({ URL(string: $0) }) else {
                NSLog("KinoLel Wünsche-Update: Versionsliste nicht lesbar, frage GitHub")
                return ausGithub(aktuell, fertig)
            }
            let version = Versionsnummer.teile(versionText)
            fertig(Versionsnummer.vergleiche(version, aktuell) > 0 ? (version: version, seite: seite) : nil)
        }.resume()
    }

    private static func ausGithub(_ aktuell: [Int], _ fertig: @escaping ((version: [Int], seite: URL)?) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases?per_page=10") else { return fertig(nil) }
        var anfrage = URLRequest(url: url, timeoutInterval: 15)
        anfrage.setValue("KinoLelWuensche-iOS/\(Marke.version)", forHTTPHeaderField: "User-Agent")
        anfrage.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: anfrage) { daten, _, _ in
            guard let daten, let releases = (try? JSONSerialization.jsonObject(with: daten)) as? [[String: Any]] else {
                return fertig(nil)
            }
            var beste = aktuell
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
            if let seite {
                fertig((version: beste, seite: seite))
            } else {
                fertig(nil)
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
