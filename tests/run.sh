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
[ "$out" = "querencia-session 0.1.0~alpha2" ] && ok "--version" || nok "--version" "$out"

# 3 --check finds labwc, configuration, panel and desktop
out=$(run sh "$S" --check); rc=$?
case $rc:$out in
0:*"labwc:       $T/bin/labwc (0.9.8)"*"Konfiguration: $T/etc/querencia/labwc"*"Panel:       $T/bin/querencia-panel"*"Arbeitsfläche: $T/bin/querencia-desktop"*) ok "--check vollständig" ;;
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
for p in panel desktop sitzung polkit benach einst; do
    printf '#!/bin/sh\necho "%s $*" >>"$FAKE/autostart.txt"\n' "$p" >"$A/$p"; chmod 755 "$A/$p"
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

# 7 user configuration only when complete
mkdir -p "$T/home/.config/querencia/labwc"
cp "$ROOT/labwc/autostart" "$T/home/.config/querencia/labwc/"
out=$(run sh "$S" --check)
case $out in *"Konfiguration: $T/etc/querencia/labwc"*) ok "unvollständige Benutzerkonfiguration ignoriert" ;; *) nok "unvollständige Benutzerkonfiguration" "$out" ;; esac
cp "$ROOT/labwc/environment" "$T/home/.config/querencia/labwc/"
out=$(run sh "$S" --check)
case $out in *"Konfiguration: $T/home/.config/querencia/labwc"*) ok "Benutzerkonfiguration gewählt" ;; *) nok "Benutzerkonfiguration" "$out" ;; esac
rm -rf "$T/home/.config/querencia/labwc"

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
    /usr/share/wayland-sessions/querencia.desktop /usr/share/applications/x-querencia-mimeapps.list; do
    [ -f "$D$f" ] || nok "installiert: $f"
done
[ -x "$D/usr/bin/querencia-session" ] && [ -x "$D/usr/libexec/querencia/querencia-screenshot-start" ] && ok "installierte Dateien und Rechte" || nok "Rechte"
cmp -s "$ROOT/bin/querencia-session" "$D/usr/bin/querencia-session" && ok "Standardpfade: Starter unverändert installiert" || nok "Starter verändert"

echo "Ergebnis: $pass bestanden, $fail fehlgeschlagen"
[ "$fail" -eq 0 ]
