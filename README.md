# KinoLel Wünsche – iPhone-App

App für **KinoLel Wünsche** (`https://wuensche.kinolel.de`, Deutsch) und **KinoLel Kívánságok**
(`https://kivansagok.kinolel.de`, Ungarisch): volle Seerr-Oberfläche in der App, oben Umschalter **Deutsch / Magyar**
(Wahl wird gemerkt), Anmeldung mit den KinoLel-Zugangsdaten bleibt gespeichert.

**Links:** Echte „Universal Links“ (normale https-Links öffnen die App) brauchen ein Apple-Entwicklerkonto (Team-ID in
`apple-app-site-association`). Bis dahin öffnet das Schema `kinolelwuensche://wuensche.kinolel.de/<pfad>` die App.

Marke/Einstellungen an einer Stelle: `settings.base` in [`project.yml`](project.yml). Bilder: `marke/wuensche_bilder.py`.
Build: GitHub Actions (macOS, XcodeGen) → unsignierte IPA + Rauchtest im Simulator; Tag `v*` → Releases.
Zum Installieren muss die IPA signiert werden (Sideloadly/AltStore oder Apple-Entwicklerkonto/TestFlight).
Updates: ohne App Store/TestFlight nicht automatisch möglich (TestFlight aktualisiert selbst).

Lizenz: MIT ([LICENSE](LICENSE)).
