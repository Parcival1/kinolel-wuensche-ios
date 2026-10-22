#!/bin/bash
# KinoLel Wünsche (iOS): Rauchtest im Simulator – starten (Wunschseite), Link-Ersatz kinolelwuensche:// auf den HU-Server,
# „Was ist neu“ einmal nach einem (simulierten) Update, beim nächsten Start nicht mehr.
set -x
APP=$1
mkdir -p rauchtest
GERAET=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
for laufzeit in sorted(d, reverse=True):
    if "iOS" not in laufzeit: continue
    for g in d[laufzeit]:
        if g["name"].startswith("iPhone"):
            print(g["udid"]); sys.exit()')
xcrun simctl boot "$GERAET"
xcrun simctl bootstatus "$GERAET" -b
xcrun simctl install "$GERAET" "$APP"
xcrun simctl launch "$GERAET" de.kinolel.wuensche
sleep 25; xcrun simctl io "$GERAET" screenshot rauchtest/01-start-25s.png
# Link-Ersatz: kinolelwuensche://kivansagok.kinolel.de/ -> App wechselt auf Magyar
xcrun simctl openurl "$GERAET" "kinolelwuensche://kivansagok.kinolel.de/"
sleep 20; xcrun simctl io "$GERAET" screenshot rauchtest/02-link-ungarisch.png
# Was ist neu (Debug-Startargument: Update von 0.1.0)
xcrun simctl terminate "$GERAET" de.kinolel.wuensche
xcrun simctl launch "$GERAET" de.kinolel.wuensche -KinoLelTestNeuigkeitenSeit 0.1.0
sleep 20; xcrun simctl io "$GERAET" screenshot rauchtest/03-neuigkeiten.png
xcrun simctl terminate "$GERAET" de.kinolel.wuensche
xcrun simctl launch "$GERAET" de.kinolel.wuensche
sleep 15; xcrun simctl io "$GERAET" screenshot rauchtest/04-zweiter-start-ohne-meldung.png
xcrun simctl spawn "$GERAET" log show --last 15m --style compact --predicate 'process == "KinoLelWuensche"' \
  | grep -E "Was ist neu" > rauchtest/neuigkeiten.txt || true
cat rauchtest/neuigkeiten.txt
exit 0
