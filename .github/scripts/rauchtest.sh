#!/bin/bash
# KinoLel Wünsche (iOS): Rauchtest im Simulator – starten (Wunschseite), Link-Ersatz kinolelwuensche:// auf den HU-Server.
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
exit 0
