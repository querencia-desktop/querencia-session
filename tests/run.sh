#!/bin/sh
# Tests for querencia-session and its files. They never start labwc or a
# panel and never talk to a running session: every test runs with an empty
# environment (env -i), a throw-away HOME and fake programs.
#
#   sh tests/run.sh            (from the repository root, or: make check)

set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d "${TMPDIR:-/tmp}/querencia-session-test.XXXXXX")
trap 'rm -rf "$T"' EXIT
pass=0 fail=0

ok() { pass=$((pass + 1)); echo "PASS $1"; }
nok() { fail=$((fail + 1)); echo "FAIL $1"; [ -z "${2-}" ] || printf '     %s\n' "$2"; }

# Fake system: bin/ with a fake labwc (version from $T/labwc-version), a
# fake panel and desktop; etc/ with the configuration of this repository.
mkdir -p "$T/bin" "$T/etc/querencia/labwc" "$T/home"
cat >"$T/bin/labwc" <<'X'
#!/bin/sh
[ "${1-}" = --version ] && { echo "labwc $(cat "$FAKE/labwc-version") (+xwayland +nls +rsvg +libsfdo)"; exit 0; }
echo "fake labwc started: $*" >>"$FAKE/started"; exit 0
X
# Fakes for the user manager, D-Bus and logind: they record their calls and
# never reach the real ones (systemctl/busctl of a test must not touch the
# running session's user manager).
cat >"$T/bin/systemctl" <<'X'
#!/bin/sh
echo "$*" >>"$FAKE/systemctl.log"
case "$*" in
*is-active*) if [ -e "$FAKE/portal-active" ]; then printf 'active\nactive\n'; else printf 'inactive\ninactive\n'; exit 3; fi ;;
*show-environment*) printf 'LANG=C.UTF-8\nPATH=/usr/bin\n' ;;
esac
exit 0
X
cat >"$T/bin/busctl" <<'X'
#!/bin/sh
echo "$*" >>"$FAKE/busctl.log"
[ -e "$FAKE/portal-answers" ]
X
cat >"$T/bin/dbus-update-activation-environment" <<'X'
#!/bin/sh
echo "$*" >>"$FAKE/dbus-env.log"
X
cat >"$T/bin/loginctl" <<'X'
#!/bin/sh
case "$*" in *"-p Seat"*) echo seat0 ;; *"-p State"*) echo closing ;; esac
X
printf '#!/bin/sh\nexit 0\n' >"$T/bin/querencia-panel"
printf '#!/bin/sh\nexit 0\n' >"$T/bin/querencia-desktop"
chmod 755 "$T/bin/"*
cp "$ROOT/labwc/environment" "$ROOT/labwc/autostart" "$ROOT/labwc/rc.xml" "$T/etc/querencia/labwc/"
echo 0.9.8 >"$T/labwc-version"

run() { # env -i with the fake system; extra VAR=value arguments first
    env -i HOME="$T/home" PATH="$T/bin:/usr/bin:/bin" FAKE="$T" \
        QUERENCIA_SYSCONFDIR="$T/etc" QUERENCIA_BINDIR="$T/bin" "$@"
}
S="$ROOT/bin/querencia-session"

# 1 syntax
for f in bin/querencia-session libexec/querencia-screenshot-start labwc/autostart tests/run.sh; do
    if sh -n "$ROOT/$f"; then ok "Syntax $f"; else nok "Syntax $f"; fi
done

# 2 version
out=$(run sh "$S" --version)
[ "$out" = "querencia-session 0.1.0~alpha5" ] && ok "--version" || nok "--version" "$out"

# 3 --check finds labwc, configuration, panel and desktop
out=$(run sh "$S" --check); rc=$?
case $rc:$out in
0:*"labwc:       $T/bin/labwc (0.9.8)"*"Vorgabe:     $T/etc/querencia/labwc"*"Konfiguration: $T/home/.config/querencia/labwc (Benutzerkopie"*"Panel:       $T/bin/querencia-panel"*"Arbeitsfläche: $T/bin/querencia-desktop"*) ok "--check vollständig" ;;
*) nok "--check vollständig" "rc=$rc $out" ;;
esac

# 3a optional programs: reported as missing, then found in BINDIR
case $out in *"Sitzung:     (nicht installiert"*"polkit-Agent: (nicht installiert)"*"Benachrichtigungen: (nicht installiert)"*"Einstellungen: (nicht installiert)"*) ok "--check ohne optionale Programme" ;;
*) nok "--check ohne optionale Programme" "$out" ;; esac
for p in querencia-sitzung querencia-polkit-agent querencia-benachrichtigungen querencia-einstellungen; do
    printf '#!/bin/sh\nexit 0\n' >"$T/bin/$p"; chmod 755 "$T/bin/$p"
done
out=$(run sh "$S" --check); rc=$?
case $rc:$out in 0:*"Sitzung:     $T/bin/querencia-sitzung"*"polkit-Agent: $T/bin/querencia-polkit-agent"*"Benachrichtigungen: $T/bin/querencia-benachrichtigungen"*"Einstellungen: $T/bin/querencia-einstellungen"*) ok "--check mit optionalen Programmen" ;;
*) nok "--check mit optionalen Programmen" "rc=$rc $out" ;; esac

# 3b autostart starts exactly what the starter passes (fake programs record
# their arguments; nothing of a real session is touched)
A=$T/autostart; mkdir -p "$A/state"
touch "$T/portal-answers"
for p in panel desktop sitzung polkit benach einst; do
    printf '#!/bin/sh\necho "%s $*" >>"$FAKE/autostart.txt"\necho "%s ${GDK_DEBUG-}" >>"$FAKE/gdk.txt"\n' "$p" "$p" >"$A/$p"; chmod 755 "$A/$p"
done
run QUERENCIA_PANEL="$A/panel" QUERENCIA_STATE_DIR="$A/state" QUERENCIA_PANEL_RECORD="$A/state/panel.pid" \
    QUERENCIA_DESKTOP="$A/desktop" QUERENCIA_DESKTOP_RECORD="$A/state/desktop.pid" \
    QUERENCIA_SITZUNG="$A/sitzung" QUERENCIA_LEERLAUF_MINUTEN=7 QUERENCIA_POLKIT_AGENT="$A/polkit" \
    QUERENCIA_BENACHRICHTIGUNGEN="$A/benach" QUERENCIA_EINSTELLUNGEN="$A/einst" sh "$ROOT/labwc/autostart"
sleep 0.5
got=$(sort "$T/autostart.txt" 2>/dev/null | tr '\n' '|')
[ "$got" = "benach |desktop |einst --bildschirm-anwenden|panel |polkit |sitzung --leerlauf 7|" ] && ok "autostart startet alle sechs" || nok "autostart startet alle sechs" "$got"
[ -s "$A/state/panel.pid" ] && [ -s "$A/state/desktop.pid" ] && ok "autostart schreibt Panel- und Desktop-Eintrag" || nok "autostart Einträge"
rm -f "$T/autostart.txt"
run QUERENCIA_PANEL="$A/panel" QUERENCIA_STATE_DIR="$A/state" QUERENCIA_PANEL_RECORD="$A/state/panel.pid" \
    QUERENCIA_DESKTOP= QUERENCIA_SITZUNG= QUERENCIA_POLKIT_AGENT= QUERENCIA_BENACHRICHTIGUNGEN= QUERENCIA_EINSTELLUNGEN= sh "$ROOT/labwc/autostart"
sleep 0.5
got=$(cat "$T/autostart.txt" 2>/dev/null | tr '\n' '|')
[ "$got" = "panel |" ] && ok "autostart ohne optionale Programme: nur Panel" || nok "autostart ohne optionale Programme" "$got"
case $(cat "$A/state/sitzung-start.log" 2>/dev/null) in *"Settings-Portal antwortet nach"*) ok "autostart: Portal-Wächter, Portal antwortet" ;; *) nok "autostart: Portal antwortet" ;; esac
[ -z "$(grep -v ' $' "$T/gdk.txt")" ] && ok "autostart: ohne no-portals, wenn das Portal antwortet" || nok "autostart: GDK_DEBUG" "$(cat "$T/gdk.txt")"
# 3c portal does not answer: GTK programs without the portal, portals
# stopped for a fresh start (fake systemctl), idle lock and display layout
# unchanged
rm -f "$T/portal-answers" "$T/autostart.txt" "$T/gdk.txt" "$T/systemctl.log" "$A/state/sitzung-start.log"
run QUERENCIA_PANEL="$A/panel" QUERENCIA_STATE_DIR="$A/state" QUERENCIA_PANEL_RECORD="$A/state/panel.pid" \
    QUERENCIA_DESKTOP="$A/desktop" QUERENCIA_DESKTOP_RECORD="$A/state/desktop.pid" \
    QUERENCIA_SITZUNG="$A/sitzung" QUERENCIA_POLKIT_AGENT="$A/polkit" \
    QUERENCIA_BENACHRICHTIGUNGEN="$A/benach" QUERENCIA_EINSTELLUNGEN="$A/einst" GDK_DEBUG=x sh "$ROOT/labwc/autostart"
sleep 0.5
got=$(sort "$T/gdk.txt" 2>/dev/null | tr '\n' '|')
[ "$got" = "benach x,no-portals|desktop x,no-portals|einst x|panel x,no-portals|polkit x,no-portals|sitzung x|" ] && ok "autostart: ohne Portal GDK_DEBUG=no-portals für GTK-Programme" || nok "autostart: ohne Portal" "$got"
case $(cat "$A/state/sitzung-start.log" 2>/dev/null) in *"antwortet nicht in 1,5 s"*) ok "autostart: Meldung ohne Portal" ;; *) nok "autostart: Meldung ohne Portal" ;; esac
grep -q 'stop xdg-desktop-portal-gtk.service xdg-desktop-portal.service' "$T/systemctl.log" 2>/dev/null && ok "autostart: Portal wird neu angestoßen" || nok "autostart: Portal-Stopp"
rm -f "$T/bin/querencia-sitzung" "$T/bin/querencia-polkit-agent" "$T/bin/querencia-benachrichtigungen" "$T/bin/querencia-einstellungen"

# 4 labwc versions
for v in 0.9.4:0 0.9.8:0 0.9.10:0 0.10.0:0 1.0:0 0.9.4-dev:0 0.9.3:1 0.8.4:1 0.9:1; do
    echo "${v%%:*}" >"$T/labwc-version"
    run sh "$S" --check >/dev/null 2>&1; rc=$?
    [ "$rc" = "${v#*:}" ] && ok "labwc ${v%%:*} -> $rc" || nok "labwc ${v%%:*}" "rc=$rc"
done
echo 0.9.3 >"$T/labwc-version"
out=$(run sh "$S" --check)
case $out in *"ZU ALT"*"nötig 0.9.4"*) ok "Meldung bei labwc 0.9.3" ;; *) nok "Meldung bei labwc 0.9.3" "$out" ;; esac
echo 0.9.8 >"$T/labwc-version"

# 5 no labwc in PATH
mkdir -p "$T/nolabwc"; cp "$T/bin/querencia-panel" "$T/nolabwc/"
out=$(env -i HOME="$T/home" PATH="$T/nolabwc:/nonexistent" QUERENCIA_SYSCONFDIR="$T/etc" QUERENCIA_BINDIR="$T/nolabwc" /bin/sh "$S" --check); rc=$?
case $rc:$out in 1:*"labwc:       FEHLT"*) ok "kein labwc" ;; *) nok "kein labwc" "rc=$rc $out" ;; esac

# 6 session.conf: DESKTOP=none, LABWC override, values are never executed
mkdir -p "$T/home/.config/querencia"
cat >"$T/home/.config/querencia/session.conf" <<X
# Kommentar
DESKTOP=none
LABWC=$T/bin/labwc
PANEL=\$(touch $T/pwned)
X
out=$(run sh "$S" --check 2>&1)
case $out in *"Arbeitsfläche: (keine)"*) ok "DESKTOP=none" ;; *) nok "DESKTOP=none" "$out" ;; esac
[ ! -e "$T/pwned" ] && ok "Werte werden nicht ausgeführt" || nok "Werte werden nicht ausgeführt"
case $out in *'Panel:       FEHLT ($(touch'*) ok "PANEL wörtlich genommen" ;; *) nok "PANEL wörtlich genommen" "$out" ;; esac
echo 'UNSINN=1' >"$T/home/.config/querencia/session.conf"
out=$(run sh "$S" --check 2>&1)
case $out in *"unbekannter Eintrag ignoriert: UNSINN"*) ok "unbekannter Eintrag gemeldet" ;; *) nok "unbekannter Eintrag" "$out" ;; esac
rm -f "$T/home/.config/querencia/session.conf"

# 7 labwc configuration: user copy kept in step with the defaults (G2-AG)
U=$T/home/.config/querencia/labwc
out=$(run sh "$S" --labwc-konfig-abgleichen 2>&1); rc=$?
[ "$rc" = 0 ] && cmp -s "$U/rc.xml" "$T/etc/querencia/labwc/rc.xml" && cmp -s "$U/.vorgabe/autostart" "$T/etc/querencia/labwc/autostart" &&
    grep -q "querencia-session 0.1.0~alpha5" "$U/.vorgabe/stand" && ok "Abgleich legt Benutzerkopie und .vorgabe an" || nok "Abgleich anlegen" "rc=$rc $out"
echo '# eigene Zeile' >>"$U/rc.xml"
cp "$T/etc/querencia/labwc/environment" "$T/env.orig"
echo 'NEU=1' >>"$T/etc/querencia/labwc/environment"
echo '<!-- neu -->' >>"$T/etc/querencia/labwc/rc.xml"
out=$(run sh "$S" --labwc-konfig-abgleichen 2>&1)
grep -qx 'NEU=1' "$U/environment" && ls "$U"/environment.vorher-* >/dev/null 2>&1 && ok "unveränderte Datei folgt der neuen Vorgabe" || nok "neue Vorgabe" "$out"
grep -q '# eigene Zeile' "$U/rc.xml" && [ -f "$U/rc.xml.vorgabe-neu" ] && ok "geänderte Datei bleibt, neue Vorgabe daneben" || nok "eigene Datei" "$out"
cp "$ROOT/labwc/rc.xml" "$T/etc/querencia/labwc/rc.xml"; cp "$T/env.orig" "$T/etc/querencia/labwc/environment"
touch "$T/home/.config/querencia/labwc-alter-weg"
out=$(run sh "$S" --check)
case $out in *"Konfiguration: $T/etc/querencia/labwc (alter Weg"*) ok "alter Weg: labwc liest die Vorgabe" ;; *) nok "alter Weg" "$out" ;; esac
rm -rf "$U" "$T/home/.config/querencia/labwc-alter-weg"

# 8 start refused outside a proper login; labwc is never started
rm -f "$T/started"
out=$(run WAYLAND_DISPLAY=wayland-9 sh "$S" 2>&1); rc=$?
case $rc:$out in 1:*"läuft bereits in einer Wayland-Sitzung"*) ok "Start in Wayland-Sitzung verweigert" ;; *) nok "Wayland" "rc=$rc $out" ;; esac
out=$(run XDG_RUNTIME_DIR="$T" sh "$S" 2>&1); rc=$?
case $rc:$out in 1:*"keine logind-Sitzung"*) ok "Start ohne logind-Sitzung verweigert" ;; *) nok "logind" "rc=$rc $out" ;; esac
out=$(run sh "$S" --bogus 2>&1); rc=$?
case $rc:$out in 1:*"unbekannte Option"*) ok "unbekannte Option" ;; *) nok "unbekannte Option" "rc=$rc $out" ;; esac
[ ! -e "$T/started" ] && ok "labwc nie gestartet" || nok "labwc gestartet!"
out=$(run sh "$S" --exit 2>&1); rc=$?
case $rc:$out in 1:*"keine laufende Querencia-Sitzung"*) ok "--exit ohne Sitzung" ;; *) nok "--exit" "rc=$rc $out" ;; esac

# 9 configuration files
if python3 -c "import sys, xml.dom.minidom as m; m.parse(sys.argv[1])" "$ROOT/labwc/rc.xml" 2>/dev/null; then ok "rc.xml wohlgeformt"; else nok "rc.xml wohlgeformt"; fi
grep -q 'command="/usr/libexec/querencia/querencia-screenshot-start"' "$ROOT/labwc/rc.xml" && ok "Druck-Taste -> libexec" || nok "Druck-Taste"
grep -q 'command="/usr/libexec/querencia/querencia-screenshot-start --window"' "$ROOT/labwc/rc.xml" && ok "Alt+Druck -> --window" || nok "Alt+Druck"
for c in "/usr/bin/querencia-sitzung --sperren --sofort" "/usr/bin/querencia-sitzung --dialog" "/usr/bin/querencia-kuerzel"; do
    grep -q "command=\"$c\"" "$ROOT/labwc/rc.xml" && ok "rc.xml: $c" || nok "rc.xml: $c"
done
grep -q '<name>Querencia-Klassisch</name>' "$ROOT/labwc/rc.xml" && ok "rc.xml: Theme Querencia-Klassisch" || nok "rc.xml: Theme"
if command -v desktop-file-validate >/dev/null; then
    out=$(desktop-file-validate "$ROOT/share/wayland-sessions/querencia.desktop" 2>&1 | grep -v 'key "DesktopNames"')
    [ -z "$out" ] && ok "Sitzungsdatei gültig (DesktopNames wie bei GDM üblich)" || nok "Sitzungsdatei" "$out"
fi
grep -qx 'Exec=/usr/bin/querencia-session' "$ROOT/share/wayland-sessions/querencia.desktop" && ok "Sitzungsdatei Exec" || nok "Sitzungsdatei Exec"
! grep -q -E '^(LANG|LANGUAGE|XKB_)' "$ROOT/labwc/environment" && ok "environment ohne Sprache/Tastatur" || nok "environment setzt Sprache/Tastatur"

# 10 no developer paths in anything that gets installed
if grep -n -E '/home/|/opt/|target/(debug|release)|projects/' "$ROOT/bin/querencia-session" "$ROOT/libexec/querencia-screenshot-start" \
    "$ROOT/labwc/"* "$ROOT/share/wayland-sessions/querencia.desktop" "$ROOT/share/applications/"*; then
    nok "keine Entwicklerpfade"
else
    ok "keine Entwicklerpfade"
fi

# 11 screenshot launcher (fake notify-send records instead of notifying)
cat >"$T/bin/notify-send" <<'X'
#!/bin/sh
echo "$*" >>"$FAKE/notified"
X
printf '#!/bin/sh\necho started >"$FAKE/shot"\n' >"$T/bin/fake-shot"
chmod 755 "$T/bin/notify-send" "$T/bin/fake-shot"
L="$ROOT/libexec/querencia-screenshot-start"
out=$(run sh "$L" 2>&1); rc=$?
case $rc:$out in 1:*"keine Wayland-Sitzung"*) ok "Druck ohne Wayland" ;; *) nok "Druck ohne Wayland" "rc=$rc $out" ;; esac
out=$(run WAYLAND_DISPLAY=x QUERENCIA_SCREENSHOT="$T/none" sh "$L" 2>&1); rc=$?
case $rc:$out in 1:*"Programm nicht installiert"*"querencia-screenshot"*) ok "Druck ohne Programm" ;; *) nok "Druck ohne Programm" "rc=$rc $out" ;; esac
sleep 0.2; [ -s "$T/notified" ] && ok "Druck ohne Programm: Benachrichtigung" || nok "Benachrichtigung"
mkdir -p "$T/state"
run WAYLAND_DISPLAY=x QUERENCIA_SCREENSHOT="$T/bin/fake-shot" QUERENCIA_STATE_DIR="$T/state" sh "$L"; rc=$?
[ "$rc" = 0 ] && [ -f "$T/shot" ] && ok "Druck startet das Programm" || nok "Druck startet das Programm" "rc=$rc"
printf '#!/bin/sh\necho "$*" >"$FAKE/shot-arg"\n' >"$T/bin/fake-shot"
run WAYLAND_DISPLAY=x QUERENCIA_SCREENSHOT="$T/bin/fake-shot" QUERENCIA_STATE_DIR="$T/state" sh "$L" --window; rc=$?
[ "$rc" = 0 ] && [ "$(cat "$T/shot-arg" 2>/dev/null)" = "--window" ] && ok "Alt+Druck gibt --window weiter" || nok "Alt+Druck --window" "rc=$rc"
out=$(run WAYLAND_DISPLAY=x QUERENCIA_SCREENSHOT="$T/bin/fake-shot" sh "$L" --boese 2>&1); rc=$?
case $rc:$out in 1:*"unbekannte Option"*) ok "Druck: unbekannte Option abgelehnt" ;; *) nok "Druck: unbekannte Option" "rc=$rc $out" ;; esac

# 12 make install into a staging directory, then the same path check
D="$T/destdir"
if make -s -C "$ROOT" install DESTDIR="$D" >/dev/null; then ok "make install"; else nok "make install"; fi
for f in /usr/bin/querencia-session /usr/libexec/querencia/querencia-screenshot-start \
    /etc/querencia/labwc/rc.xml /etc/querencia/labwc/environment /etc/querencia/labwc/autostart \
    /usr/share/wayland-sessions/querencia.desktop /usr/share/applications/x-querencia-mimeapps.list \
    /usr/share/xdg-desktop-portal/x-querencia-portals.conf; do
    [ -f "$D$f" ] || nok "installiert: $f"
done
[ -x "$D/usr/bin/querencia-session" ] && [ -x "$D/usr/libexec/querencia/querencia-screenshot-start" ] && ok "installierte Dateien und Rechte" || nok "Rechte"
cmp -s "$ROOT/bin/querencia-session" "$D/usr/bin/querencia-session" && ok "Standardpfade: Starter unverändert installiert" || nok "Starter verändert"

# 13 a whole start with a fake labwc: user copy, locale and desktop for
# D-Bus activation, fresh portals before and after, values put back, logs
# with five generations (fakes only; the real user manager is never asked)
cat >"$T/bin/labwc" <<'X'
#!/bin/sh
[ "${1-}" = --version ] && { echo "labwc $(cat "$FAKE/labwc-version") (+xwayland +nls +rsvg +libsfdo)"; exit 0; }
echo "fake labwc started: $* QE_LABWC_VORGABE=${QE_LABWC_VORGABE-} LANG=${LANG-}" >>"$FAKE/started"; exit 0
X
chmod 755 "$T/bin/labwc"
mkdir -p "$T/run" "$T/home/.local/state/querencia"
for i in 1 2 3 4 5; do echo "alt $i" >"$T/home/.local/state/querencia/panel.log.$i"; done
echo "vorige" >"$T/home/.local/state/querencia/panel.log"
rm -f "$T/started" "$T/systemctl.log" "$T/dbus-env.log"; touch "$T/portal-active"
run XDG_RUNTIME_DIR="$T/run" XDG_SESSION_ID=7 LANG=de_DE.UTF-8 sh "$S" >"$T/start.out" 2>&1; rc=$?
SL=$T/home/.local/state/querencia/sitzung-start.log
[ "$rc" = 0 ] && grep -q "fake labwc started: -C $T/home/.config/querencia/labwc QE_LABWC_VORGABE=$T/etc/querencia/labwc LANG=de_DE.UTF-8" "$T/started" 2>/dev/null &&
    ok "Start: labwc liest die Benutzerkopie, QE_LABWC_VORGABE gesetzt" || nok "Start" "rc=$rc $(cat "$T/start.out" "$SL" 2>/dev/null)"
order=$(grep -o -e 'Aktivierungsumgebung gesetzt' -e 'Portale gestoppt (vor dem Start' -e 'starte ' -e 'Portale gestoppt (nach dem Ende' -e 'Aktivierungsumgebung zurückgesetzt' -e 'labwc beendet' "$SL" | tr '\n' '|')
[ "$order" = "Aktivierungsumgebung gesetzt|Portale gestoppt (vor dem Start|starte |Portale gestoppt (nach dem Ende|Aktivierungsumgebung zurückgesetzt|labwc beendet|" ] &&
    ok "Start: Reihenfolge Aktivierung, Portale, labwc, Portale, Rücknahme" || nok "Start: Reihenfolge" "$order"
grep -q 'set-environment LANG=de_DE.UTF-8 XDG_CURRENT_DESKTOP=X-Querencia XDG_SESSION_TYPE=wayland XDG_SESSION_DESKTOP=querencia XCURSOR_THEME=DMZ-White XCURSOR_SIZE=24' "$T/systemctl.log" &&
    grep -q 'LANG=de_DE.UTF-8 XDG_CURRENT_DESKTOP=X-Querencia' "$T/dbus-env.log" && ok "Start: Locale und Desktop für systemd und D-Bus (QD-064)" || nok "Start: Aktivierungsumgebung" "$(cat "$T/systemctl.log")"
grep -q 'set-environment LANG=C.UTF-8' "$T/systemctl.log" && grep -q 'unset-environment XDG_CURRENT_DESKTOP' "$T/systemctl.log" &&
    ok "Start: alte Werte nach dem Ende zurück" || nok "Start: Rücknahme" "$(cat "$T/systemctl.log")"
[ "$(grep -c 'reset-failed xdg-desktop-portal-gtk.service xdg-desktop-portal.service' "$T/systemctl.log")" = 4 ] && ok "Start: reset-failed vor und nach jedem Portal-Stopp" || nok "Start: reset-failed"
[ "$(cat "$T/home/.local/state/querencia/panel.log.1")" = vorige ] && [ "$(cat "$T/home/.local/state/querencia/panel.log.5")" = "alt 4" ] &&
    ok "Start: fünf Log-Generationen" || nok "Start: Log-Generationen"
[ -f "$T/home/.config/querencia/labwc/.vorgabe/stand" ] && ok "Start: Benutzerkopie abgeglichen" || nok "Start: Benutzerkopie"
[ ! -e "$T/home/.local/state/querencia/aktivierungsumgebung.vorher" ] && ok "Start: Sicherung der Aktivierungsumgebung aufgeräumt" || nok "Start: Sicherung"
rm -f "$T/portal-active"

echo "Ergebnis: $pass bestanden, $fail fehlgeschlagen"
[ "$fail" -eq 0 ]
