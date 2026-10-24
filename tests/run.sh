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
# Fake renderer probe (software OpenGL, QD-169): eglinfo reports the renderer
# from $T/renderer, or hangs with $T/egl-haengt (its PID goes to
# $T/haenger.pids, the tests end it themselves). Render nodes come from a
# fake /sys/class/drm (QUERENCIA_DRM_SYSFS); by default none, so no test
# ever asks the real graphics driver.
cat >"$T/bin/eglinfo" <<'X'
#!/bin/sh
echo "$*" >>"$FAKE/eglinfo.log"
if [ -e "$FAKE/egl-haengt" ]; then echo $$ >>"$FAKE/haenger.pids"; exec sleep 30; fi
[ -r "$FAKE/renderer" ] || { echo "eglinfo: kein Gerät" >&2; exit 1; }
echo "EGL client extensions string:"
echo "OpenGL ES profile renderer: $(cat "$FAKE/renderer")"
X
chmod 755 "$T/bin/eglinfo"
mkdir -p "$T/drm-leer"
# Fake DRM class directory with one render node per kernel driver $@; prints
# its path.
drm() {
    d=$T/drm-$(echo "$*" | tr ' ' '-')
    rm -rf "$d"; mkdir -p "$d"; n=128
    for treiber in "$@"; do
        mkdir -p "$T/treiber/$treiber" "$d/renderD$n/device"
        ln -s "$T/treiber/$treiber" "$d/renderD$n/device/driver"
        n=$((n + 1))
    done
    echo "$d"
}
SW="LIBGL_ALWAYS_SOFTWARE=1 MESA_LOADER_DRIVER_OVERRIDE=llvmpipe GALLIUM_DRIVER=llvmpipe"
ZINK="zink Vulkan 1.4(NVIDIA GeForce RTX 3060 (NVK GA106) (MESA_NVK))"

run() { # env -i with the fake system; extra VAR=value arguments first
    env -i HOME="$T/home" PATH="$T/bin:/usr/bin:/bin" FAKE="$T" \
        QUERENCIA_SYSCONFDIR="$T/etc" QUERENCIA_BINDIR="$T/bin" QUERENCIA_DRM_SYSFS="$T/drm-leer" "$@"
}
S="$ROOT/bin/querencia-session"

# 1 syntax
for f in bin/querencia-session libexec/querencia-screenshot-start labwc/autostart tests/run.sh; do
    if sh -n "$ROOT/$f"; then ok "Syntax $f"; else nok "Syntax $f"; fi
done

# 2 version
out=$(run sh "$S" --version)
[ "$out" = "querencia-session 0.1.0~alpha10" ] && ok "--version" || nok "--version" "$out"

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
# The autostart asks the panel for its capabilities (--faehigkeiten); the
# fake answers without recording. Like Panel 0.2.3 it names "ueberwacht",
# so the panel starts under its watchdog; with $FAKE/panel-alt it acts as an
# older panel without the capability.
printf '#!/bin/sh\nif [ "${1-}" = --faehigkeiten ]; then [ -e "$FAKE/panel-alt" ] || echo ueberwacht; exit 0; fi\necho "panel $*" >>"$FAKE/autostart.txt"\necho "panel ${GDK_DEBUG-}" >>"$FAKE/gdk.txt"\n' >"$A/panel"; chmod 755 "$A/panel"
run QUERENCIA_PANEL="$A/panel" QUERENCIA_STATE_DIR="$A/state" QUERENCIA_PANEL_RECORD="$A/state/panel.pid" \
    QUERENCIA_DESKTOP="$A/desktop" QUERENCIA_DESKTOP_RECORD="$A/state/desktop.pid" \
    QUERENCIA_SITZUNG="$A/sitzung" QUERENCIA_LEERLAUF_MINUTEN=7 QUERENCIA_POLKIT_AGENT="$A/polkit" \
    QUERENCIA_BENACHRICHTIGUNGEN="$A/benach" QUERENCIA_EINSTELLUNGEN="$A/einst" sh "$ROOT/labwc/autostart"
sleep 0.5
got=$(sort "$T/autostart.txt" 2>/dev/null | tr '\n' '|')
[ "$got" = "benach |desktop |einst --bildschirm-anwenden|panel --ueberwacht|polkit |sitzung --leerlauf 7|" ] && ok "autostart startet alle sechs, Panel unter Überwachung" || nok "autostart startet alle sechs" "$got"
[ -s "$A/state/panel.pid" ] && [ -s "$A/state/desktop.pid" ] && ok "autostart schreibt Panel- und Desktop-Eintrag" || nok "autostart Einträge"
rm -f "$T/autostart.txt"
run QUERENCIA_PANEL="$A/panel" QUERENCIA_STATE_DIR="$A/state" QUERENCIA_PANEL_RECORD="$A/state/panel.pid" \
    QUERENCIA_DESKTOP= QUERENCIA_SITZUNG= QUERENCIA_POLKIT_AGENT= QUERENCIA_BENACHRICHTIGUNGEN= QUERENCIA_EINSTELLUNGEN= sh "$ROOT/labwc/autostart"
sleep 0.5
got=$(cat "$T/autostart.txt" 2>/dev/null | tr '\n' '|')
[ "$got" = "panel --ueberwacht|" ] && ok "autostart ohne optionale Programme: nur Panel" || nok "autostart ohne optionale Programme" "$got"
# an older panel without the capability starts as before, without --ueberwacht
rm -f "$T/autostart.txt" "$A/state/panel.pid"; touch "$T/panel-alt"
run QUERENCIA_PANEL="$A/panel" QUERENCIA_STATE_DIR="$A/state" QUERENCIA_PANEL_RECORD="$A/state/panel.pid" \
    QUERENCIA_DESKTOP= QUERENCIA_SITZUNG= QUERENCIA_POLKIT_AGENT= QUERENCIA_BENACHRICHTIGUNGEN= QUERENCIA_EINSTELLUNGEN= sh "$ROOT/labwc/autostart"
sleep 0.5
got=$(cat "$T/autostart.txt" 2>/dev/null | tr '\n' '|')
[ "$got" = "panel |" ] && [ -s "$A/state/panel.pid" ] && ok "autostart: älteres Panel ohne Überwachung" || nok "autostart: älteres Panel" "$got"
rm -f "$T/panel-alt" "$T/autostart.txt"
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
# 3d software OpenGL: autostart exports exactly the three names from
# QUERENCIA_GRAFIK_UMGEBUNG to what it starts, nothing else
touch "$T/portal-answers"
printf '#!/bin/sh\n[ "${1-}" = --faehigkeiten ] && exit 0\nenv | grep -E "^(LIBGL_|MESA_|GALLIUM_|VK_|FREMD=)" | sort >"$FAKE/panel-env"\n' >"$A/panel"; chmod 755 "$A/panel"
rm -f "$T/panel-env"
run QUERENCIA_PANEL="$A/panel" QUERENCIA_STATE_DIR="$A/state" QUERENCIA_PANEL_RECORD="$A/state/panel.pid" \
    QUERENCIA_GRAFIK_UMGEBUNG="$SW FREMD=1 VK_ICD_FILENAMES=x" sh "$ROOT/labwc/autostart"
sleep 0.5
got=$(tr '\n' ' ' <"$T/panel-env" 2>/dev/null)
[ "$got" = "GALLIUM_DRIVER=llvmpipe LIBGL_ALWAYS_SOFTWARE=1 MESA_LOADER_DRIVER_OVERRIDE=llvmpipe " ] &&
    ok "autostart: Software-OpenGL genau die drei Namen an das Panel" || nok "autostart: Software-OpenGL" "$got"
rm -f "$T/panel-env"
run QUERENCIA_PANEL="$A/panel" QUERENCIA_STATE_DIR="$A/state" QUERENCIA_PANEL_RECORD="$A/state/panel.pid" \
    QUERENCIA_GRAFIK_UMGEBUNG= sh "$ROOT/labwc/autostart"
sleep 0.5
[ -f "$T/panel-env" ] && [ ! -s "$T/panel-env" ] && ok "autostart: ohne QUERENCIA_GRAFIK_UMGEBUNG nichts gesetzt" || nok "autostart: leer" "$(cat "$T/panel-env" 2>/dev/null)"
rm -f "$T/portal-answers" "$T/panel-env"

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
    grep -q "querencia-session 0.1.0~alpha10" "$U/.vorgabe/stand" && ok "Abgleich legt Benutzerkopie und .vorgabe an" || nok "Abgleich anlegen" "rc=$rc $out"
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
grep -A2 '<keybind key="W-d">' "$ROOT/labwc/rc.xml" | grep -q 'org.querencia.Panel.ArbeitsflaecheUmschalten' && ok "rc.xml: W-d Arbeitsfläche anzeigen (QD-078)" || nok "rc.xml: W-d"
grep -A2 '<keybind key="W-d">' "$ROOT/labwc/rc.xml" | grep -q -- '--dest org.querencia.Panel --object-path /org/querencia/Panel ' && ok "rc.xml: W-d an org.querencia.Panel" || nok "rc.xml: W-d Busname"
grep -qx 'inode/directory=org.querencia.Dateien.desktop' "$ROOT/share/applications/x-querencia-mimeapps.list" && ok "mimeapps: Ordner mit org.querencia.Dateien" || nok "mimeapps: inode/directory"
! grep -v '^#' "$ROOT/share/applications/x-querencia-mimeapps.list" | grep -q 'io.github.lgse.Strata' && ok "mimeapps: alte Files-ID nicht mehr genannt" || nok "mimeapps: alte Files-ID"
for k in W-f A-F11; do
    grep -A1 "<keybind key=\"$k\">" "$ROOT/labwc/rc.xml" | grep -q 'ToggleFullscreen' && ok "rc.xml: $k Vollbild (QD-065)" || nok "rc.xml: $k Vollbild"
done
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

# 14 software OpenGL (QD-169): decision with --grafik-pruefen, which starts
# and changes nothing; fake render nodes, fake eglinfo and querencia-sitzung
grafik() { # sysfs, then extra VAR=value arguments
    sysfs=$1; shift
    rm -f "$T/eglinfo.log"
    run QUERENCIA_DRM_SYSFS="$sysfs" "$@" sh "$S" --grafik-pruefen 2>&1
}
echo "$ZINK" >"$T/renderer"
out=$(grafik "$(drm nouveau)")
case $out in *"Grafik: Software-OpenGL für die Sitzung: $SW (zink auf NVK/nouveau; Renderer „$ZINK“ (Kerneltreiber nouveau, Prüfung "*" ms über eglinfo -B -p surfaceless, gewartet "*) ok "Grafik: zink auf NVK, nouveau -> Software-OpenGL" ;;
*) nok "Grafik: zink auf NVK" "$out" ;; esac
grep -qx -- '-B -p surfaceless -a gles' "$T/eglinfo.log" 2>/dev/null && ok "Grafik: eglinfo surfaceless GLES gefragt" || nok "Grafik: eglinfo-Aufruf" "$(cat "$T/eglinfo.log" 2>/dev/null)"
for treiber in amdgpu i915 nvidia; do
    out=$(grafik "$(drm $treiber)")
    case $out in *"Grafik: OpenGL unverändert (Kerneltreiber $treiber, kein nouveau: nicht geprüft)") ;;
    *) nok "Grafik: $treiber" "$out"; continue ;; esac
    [ ! -e "$T/eglinfo.log" ] && ok "Grafik: $treiber -> nichts, nicht geprüft" || nok "Grafik: $treiber geprüft"
done
out=$(grafik "$T/drm-leer")
case $out in *"(Kerneltreiber keiner, kein nouveau: nicht geprüft)") ok "Grafik: kein Render-Knoten -> nichts" ;; *) nok "Grafik: kein Render-Knoten" "$out" ;; esac
for r in "NV106" "llvmpipe (LLVM 20.1.8, 256 bits)"; do
    echo "$r" >"$T/renderer"
    out=$(grafik "$(drm nouveau)")
    case $out in *"Grafik: OpenGL unverändert (kein zink auf NVK/nouveau; Renderer „$r“"*) ok "Grafik: nouveau mit $r -> nichts" ;; *) nok "Grafik: $r" "$out" ;; esac
done
echo "AMD Radeon RX 6600 (radeonsi, navi23, LLVM 20.1.8, DRM 3.64)" >"$T/renderer"
out=$(grafik "$(drm amdgpu nouveau)")
case $out in *"OpenGL unverändert (kein zink auf NVK/nouveau; Renderer „AMD Radeon"*"(Kerneltreiber amdgpu nouveau, Prüfung"*) ok "Grafik: zwei Karten, radeonsi -> geprüft, nichts" ;; *) nok "Grafik: zwei Karten" "$out" ;; esac
rm -f "$T/renderer"
out=$(grafik "$(drm nouveau)")
case $out in *"OpenGL unverändert (Renderer unbekannt (Prüfung ohne Ergebnis nach "*"eglinfo: kein Gerät"*) ok "Grafik: Prüfung scheitert -> nichts" ;; *) nok "Grafik: Prüfung scheitert" "$out" ;; esac
# querencia-sitzung --grafik-pruefen first (Querencia Sitzung 0.1.8); an
# older one without the option leaves it to eglinfo
printf '#!/bin/sh\n[ "${1-}" = --grafik-pruefen ] || exit 2\n[ -e "$FAKE/sitzung-alt" ] && { echo "unbekannte Option: $1" >&2; exit 2; }\nprintf "renderer=%%s\\nvendor=Mesa\\n" "$(cat "$FAKE/sitzung-renderer")"\n' >"$T/bin/querencia-sitzung"
chmod 755 "$T/bin/querencia-sitzung"
echo "$ZINK" >"$T/sitzung-renderer"
out=$(grafik "$(drm nouveau)")
case $out in *"Software-OpenGL für die Sitzung: $SW (zink auf NVK/nouveau;"*"über querencia-sitzung --grafik-pruefen"*) ;; *) nok "Grafik: über querencia-sitzung" "$out" ;; esac
[ ! -e "$T/eglinfo.log" ] && ok "Grafik: querencia-sitzung --grafik-pruefen zuerst, kein eglinfo" || nok "Grafik: eglinfo trotz querencia-sitzung"
touch "$T/sitzung-alt"; echo "$ZINK" >"$T/renderer"
out=$(grafik "$(drm nouveau)")
case $out in *"Software-OpenGL für die Sitzung: $SW"*"über eglinfo -B -p surfaceless"*) ok "Grafik: ältere querencia-sitzung -> eglinfo" ;; *) nok "Grafik: ältere querencia-sitzung" "$out" ;; esac
rm -f "$T/bin/querencia-sitzung" "$T/sitzung-alt" "$T/sitzung-renderer"
# a probe that hangs: at most 2 s, then nothing; the hanging process is
# not waited for
touch "$T/egl-haengt"; rm -f "$T/haenger.pids"
t0=$(date +%s%N)
out=$(grafik "$(drm nouveau)")
ms=$((($(date +%s%N) - t0) / 1000000))
case $out in *"OpenGL unverändert (Renderer unbekannt (Prüfung ohne Ergebnis in 2000 ms (Zeitgrenze), gewartet "*) ;; *) nok "Grafik: Hänger" "$out" ;; esac
[ "$ms" -ge 1900 ] && [ "$ms" -lt 3500 ] && ok "Grafik: Prüfung hängt -> Zeitgrenze 2 s, nichts ($ms ms)" || nok "Grafik: Hänger Dauer" "$ms ms"
haenger=$(cat "$T/haenger.pids" 2>/dev/null)
[ -n "$haenger" ] && kill -0 $haenger 2>/dev/null && ok "Grafik: hängende Prüfung läuft noch, Starter wartete nicht darauf" || nok "Grafik: Hänger-Prozess" "$haenger"
[ -z "$haenger" ] || kill $haenger 2>/dev/null
rm -f "$T/egl-haengt" "$T/haenger.pids"
# grafik.ini: an, aus, unknown value, key in another section
mkdir -p "$T/home/.config/querencia"; GI=$T/home/.config/querencia/grafik.ini
printf '[Grafik]\nSoftware-OpenGL = An\n' >"$GI"
out=$(grafik "$(drm amdgpu)")
case $out in *"Software-OpenGL für die Sitzung: $SW (Software-OpenGL=an in $GI)") [ ! -e "$T/eglinfo.log" ] && ok "Grafik: grafik.ini an (Großschreibung) -> Software-OpenGL ohne Prüfung" || nok "Grafik: an geprüft" ;;
*) nok "Grafik: grafik.ini an" "$out" ;; esac
printf '# Kommentar\n[Grafik]\nSoftware-OpenGL=aus\n' >"$GI"
out=$(grafik "$(drm nouveau)")
case $out in *"OpenGL unverändert (Software-OpenGL=aus in $GI)") [ ! -e "$T/eglinfo.log" ] && ok "Grafik: grafik.ini aus -> nichts, nicht geprüft" || nok "Grafik: aus geprüft" ;;
*) nok "Grafik: grafik.ini aus" "$out" ;; esac
printf '[Grafik]\nSoftware-OpenGL = vielleicht\n' >"$GI"
out=$(grafik "$(drm nouveau)")
case $out in *"Software-OpenGL für die Sitzung: $SW (zink auf NVK/nouveau;"*"; unbekannter Wert „vielleicht“ in $GI, gilt automatisch") ok "Grafik: unbekannter Wert -> automatisch mit Hinweis" ;; *) nok "Grafik: unbekannter Wert" "$out" ;; esac
printf '[Anderes]\nSoftware-OpenGL = an\n' >"$GI"
out=$(grafik "$(drm amdgpu)")
case $out in *"OpenGL unverändert (Kerneltreiber amdgpu, kein nouveau: nicht geprüft)") ok "Grafik: Schlüssel außerhalb von [Grafik] zählt nicht" ;; *) nok "Grafik: anderer Abschnitt" "$out" ;; esac
rm -f "$GI"

# 15 whole starts with software OpenGL: the fake labwc runs the autostart
# file of its configuration like labwc does and records its own
# environment; the fake panel records what it gets
cat >"$T/bin/labwc" <<'X'
#!/bin/sh
[ "${1-}" = --version ] && { echo "labwc $(cat "$FAKE/labwc-version") (+xwayland +nls +rsvg +libsfdo)"; exit 0; }
echo "fake labwc started: $*" >>"$FAKE/started"
env | grep -E "^(LIBGL_|MESA_|GALLIUM_|VK_|QUERENCIA_GRAFIK_UMGEBUNG=)" | sort >"$FAKE/labwc-env"
sh "$2/autostart" </dev/null >/dev/null 2>&1
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -e "$FAKE/panel-env" ] && break; sleep 0.1; done
exit 0
X
cp "$T/bin/querencia-panel" "$T/panel.orig"
printf '#!/bin/sh\n[ "${1-}" = --faehigkeiten ] && exit 0\nenv | grep -E "^(LIBGL_|MESA_|GALLIUM_|VK_)" | sort >"$FAKE/panel-env"\n' >"$T/bin/querencia-panel"
chmod 755 "$T/bin/labwc" "$T/bin/querencia-panel"
touch "$T/portal-answers"
start() { # sysfs; runs a whole start, sets rc and ms
    rm -f "$T/started" "$T/systemctl.log" "$T/dbus-env.log" "$T/labwc-env" "$T/panel-env" "$T/eglinfo.log" "$SL"
    t0=$(date +%s%N)
    run QUERENCIA_DRM_SYSFS="$1" XDG_RUNTIME_DIR="$T/run" XDG_SESSION_ID=7 LANG=de_DE.UTF-8 sh "$S" >"$T/start.out" 2>&1; rc=$?
    ms=$((($(date +%s%N) - t0) / 1000000))
}
echo "$ZINK" >"$T/renderer"
start "$(drm nouveau)"
[ "$rc" = 0 ] && [ -e "$T/started" ] && [ "$(cat "$T/labwc-env" 2>/dev/null)" = "QUERENCIA_GRAFIK_UMGEBUNG=$SW" ] &&
    ok "Start zink: labwc ohne die drei Variablen, nur QUERENCIA_GRAFIK_UMGEBUNG" || nok "Start zink: labwc" "rc=$rc $(cat "$T/labwc-env" "$T/start.out" 2>/dev/null)"
got=$(tr '\n' ' ' <"$T/panel-env" 2>/dev/null)
[ "$got" = "GALLIUM_DRIVER=llvmpipe LIBGL_ALWAYS_SOFTWARE=1 MESA_LOADER_DRIVER_OVERRIDE=llvmpipe " ] &&
    ok "Start zink: Panel (Autostart) mit den drei Variablen, ohne VK_*" || nok "Start zink: Panel" "$got"
grep 'set-environment LANG=' "$T/systemctl.log" | grep -q " $SW\$" && grep -q " $SW\$" "$T/dbus-env.log" &&
    ok "Start zink: Software-OpenGL in der Aktivierungsumgebung (systemd, D-Bus)" || nok "Start zink: Aktivierung" "$(cat "$T/systemctl.log" "$T/dbus-env.log" 2>/dev/null)"
grep -q 'unset-environment .*LIBGL_ALWAYS_SOFTWARE MESA_LOADER_DRIVER_OVERRIDE GALLIUM_DRIVER' "$T/systemctl.log" &&
    ok "Start zink: nach dem Ende aus der Aktivierungsumgebung entfernt" || nok "Start zink: Rücknahme" "$(cat "$T/systemctl.log")"
grep -q "Grafik: Software-OpenGL für die Sitzung: $SW (zink auf NVK/nouveau;" "$SL" && ! grep -q 'übernimmt QUERENCIA_GRAFIK_UMGEBUNG nicht' "$SL" &&
    ok "Start zink: Protokollzeile in sitzung-start.log" || nok "Start zink: Protokoll" "$(grep Grafik "$SL")"
order=$(grep -o -e 'Grafik: ' -e 'Aktivierungsumgebung gesetzt' -e 'starte ' "$SL" | tr '\n' '|')
[ "$order" = "Grafik: |Aktivierungsumgebung gesetzt|starte |" ] && ok "Start zink: Entscheidung vor Aktivierung und labwc" || nok "Start zink: Reihenfolge" "$order"
[ -z "$(ls "$T/home/.local/state/querencia" | grep grafik-pruefung)" ] && ok "Start zink: keine Prüfdateien übrig" || nok "Start zink: Prüfdateien" "$(ls "$T/home/.local/state/querencia")"
# another driver: nothing anywhere, no probe
start "$(drm amdgpu)"
[ "$rc" = 0 ] && [ "$(cat "$T/labwc-env" 2>/dev/null)" = "QUERENCIA_GRAFIK_UMGEBUNG=" ] && [ -f "$T/panel-env" ] && [ ! -s "$T/panel-env" ] &&
    ! grep -q -e LIBGL_ -e MESA_LOADER -e GALLIUM_ "$T/systemctl.log" "$T/dbus-env.log" && [ ! -e "$T/eglinfo.log" ] &&
    grep -q 'Grafik: OpenGL unverändert (Kerneltreiber amdgpu, kein nouveau: nicht geprüft)' "$SL" &&
    ok "Start amdgpu: nichts gesetzt, nicht geprüft, Protokollzeile" || nok "Start amdgpu" "rc=$rc $(cat "$T/labwc-env" "$T/panel-env" "$T/systemctl.log" 2>/dev/null)"
# a hanging probe: nothing set, the start goes on after at most 2 s
touch "$T/egl-haengt"; rm -f "$T/haenger.pids"
start "$(drm nouveau)"
haenger=$(cat "$T/haenger.pids" 2>/dev/null)
gewartet=$(sed -n 's/.*Zeitgrenze), gewartet \([0-9]*\) ms.*/\1/p' "$SL")
[ "$rc" = 0 ] && [ -e "$T/started" ] && [ -n "$gewartet" ] && [ "$gewartet" -le 2100 ] && [ -f "$T/panel-env" ] && [ ! -s "$T/panel-env" ] &&
    ! grep -q LIBGL_ "$T/systemctl.log" && ok "Start Hänger: Zeitgrenze, nichts gesetzt, labwc gestartet (gewartet $gewartet ms, Start $ms ms)" ||
    nok "Start Hänger" "rc=$rc gewartet=$gewartet $(grep Grafik "$SL")"
[ -n "$haenger" ] && kill -0 $haenger 2>/dev/null && ok "Start Hänger: Starter beendet, hängende Prüfung läuft noch" || nok "Start Hänger: Prozess" "$haenger"
[ -z "$haenger" ] || kill $haenger 2>/dev/null
rm -f "$T/egl-haengt" "$T/haenger.pids"
# an own autostart without the block: a note, software OpenGL only for
# activation
printf '# eigene autostart\n' >"$T/home/.config/querencia/labwc/autostart"
start "$(drm nouveau)"
grep -q 'autostart übernimmt QUERENCIA_GRAFIK_UMGEBUNG nicht (eigene Datei?)' "$SL" && grep 'set-environment LANG=' "$T/systemctl.log" | grep -q " $SW\$" &&
    ok "Start mit eigener autostart: Hinweis, Software-OpenGL nur über die Aktivierung" || nok "Start eigene autostart" "$(grep Grafik "$SL")"
rm -rf "$T/home/.config/querencia/labwc" "$T/renderer" "$T/portal-answers"
cp "$T/panel.orig" "$T/bin/querencia-panel"

echo "Ergebnis: $pass bestanden, $fail fehlgeschlagen"
[ "$fail" -eq 0 ]
