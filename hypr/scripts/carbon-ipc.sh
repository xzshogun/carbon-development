#!/bin/sh
# Carbon IPC client: send one command to the shell over its unix socket (/tmp/carbon-shell.sock).
# Automatically boots Quickshell if not yet running in the current Wayland session.
cmd="$*"
[ -z "$cmd" ] && cmd="toggle-launcher"

if [ ! -S "/tmp/carbon-shell.sock" ] && ! pgrep -x quickshell >/dev/null 2>&1; then
    QS_DIR="$HOME/.local/share/quickshell/carbon"
    if [ -d "$QS_DIR" ]; then
        mkdir -p "$HOME/.config/quickshell" 2>/dev/null || true
        ln -sfn "$QS_DIR" "$HOME/.config/quickshell/carbon" 2>/dev/null || true
        if [ -x "$HOME/.local/bin/quickshell" ]; then
            nohup "$HOME/.local/bin/quickshell" -p "$QS_DIR" >/tmp/carbon-quickshell.log 2>&1 &
        elif command -v quickshell >/dev/null 2>&1; then
            nohup quickshell -p "$QS_DIR" >/tmp/carbon-quickshell.log 2>&1 &
        elif [ -x "/usr/bin/quickshell" ]; then
            nohup /usr/bin/quickshell -p "$QS_DIR" >/tmp/carbon-quickshell.log 2>&1 &
        fi
        for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
            [ -S "/tmp/carbon-shell.sock" ] && break
            sleep 0.1
        done
    fi
fi

exec python3 -c '
import socket, sys
cmd = sys.argv[1] if len(sys.argv) > 1 else ""
path = "/tmp/carbon-shell.sock"
try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(0.8)
    s.connect(path)
    s.sendall((cmd + "\n").encode())
    try:
        s.shutdown(socket.SHUT_WR)
    except Exception:
        pass
    s.close()
except Exception:
    pass
sys.exit(0)
' "$cmd"