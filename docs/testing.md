# Testen – querencia-session

```bash
sh tests/run.sh       # oder: make check
```

Die Tests laufen mit leerer Umgebung (`env -i`), eigenem Wegwerf-`HOME`,
einem gefälschten `labwc` und gefälschten Programmen. Sie starten nie labwc,
nie ein Panel und sprechen keine laufende Sitzung an. Geprüft werden u. a.
labwc-Versionsgrenze (0.9.3 abgelehnt), `--check`, `session.conf`
(Werte werden nie ausgeführt), Wahl der Benutzer- bzw. Systemkonfiguration,
Verweigerung in einer bestehenden Wayland-Sitzung und ohne logind,
Sitzungsdatei, Druck-Taste und eine Probeinstallation ohne Entwicklerpfade.
Seit 0.1.0~alpha4 außerdem: Abgleich der Benutzerkopie (`.vorgabe/`,
`.vorgabe-neu`, `.vorher-*`, alter Weg), der Portal-Wächter im autostart
(mit und ohne antwortendes Portal) und ein ganzer Start mit gefälschtem
labwc: Aktivierungsumgebung, Portal-Reset vor und nach labwc, Rücknahme,
fünf Log-Generationen. `systemctl`, `busctl`, `loginctl` und
`dbus-update-activation-environment` sind dabei Attrappen, die nur
mitschreiben; der echte User-Manager wird nie angesprochen.

Nicht abgedeckt (braucht eine echte Anmeldung, siehe `docs/TESTING.md` im
Repository `querencia`): Start des echten labwc, Panel und Desktop,
Abmelden, Aufräumen übrig gebliebener Prozesse, echte Portale.
