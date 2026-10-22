// KinoLel Wünsche (iOS): Start. Öffnet die Wunschseite (Seerr) in einer Web-Ansicht mit Umschalter Deutsch/Magyar.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Vor dem ersten WKWebView: erkennt Neuinstallation/Update für „Was ist neu“
        Neuigkeiten.vorbereiten()
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let konfig = UISceneConfiguration(name: "Standard", sessionRole: connectingSceneSession.role)
        konfig.delegateClass = SceneDelegate.self
        return konfig
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let ansicht = WunschViewController()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let fensterSzene = scene as? UIWindowScene else { return }
        let fenster = UIWindow(windowScene: fensterSzene)
        fenster.rootViewController = ansicht
        fenster.backgroundColor = Marke.grund
        fenster.makeKeyAndVisible()
        window = fenster
        if let url = connectionOptions.urlContexts.first?.url { ansicht.oeffne(schemaUrl: url) }
    }

    // kinolelwuensche://wuensche.kinolel.de/... (Ersatz für Universal Links)
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url { ansicht.oeffne(schemaUrl: url) }
    }
}

enum Marke {
    static let appName = Bundle.main.object(forInfoDictionaryKey: "KinoLelAppName") as? String ?? "KinoLel Wünsche"
    static let serverDE = URL(string: Bundle.main.object(forInfoDictionaryKey: "KinoLelServerDE") as? String ?? "https://wuensche.kinolel.de")!
    static let serverHU = URL(string: Bundle.main.object(forInfoDictionaryKey: "KinoLelServerHU") as? String ?? "https://kivansagok.kinolel.de")!
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    static let lavendel = UIColor(red: 0x9A / 255.0, green: 0xA4 / 255.0, blue: 0xFF / 255.0, alpha: 1)
    static let grund = UIColor(red: 0x0B / 255.0, green: 0x0F / 255.0, blue: 0x18 / 255.0, alpha: 1)
    static var ungarisch: Bool { Sprache.aktuell == .hu }
}
