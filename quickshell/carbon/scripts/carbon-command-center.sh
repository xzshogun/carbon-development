#!/bin/sh
# Trigger Carbon Notch Command Center toggle
if [ -x "${HOME}/.config/hypr/scripts/carbon-ipc.sh" ]; then
    exec sh "${HOME}/.config/hypr/scripts/carbon-ipc.sh" command-center
elif [ -x "${HOME}/.config/carbon/scripts/carbon-ipc.sh" ]; then
    exec sh "${HOME}/.config/carbon/scripts/carbon-ipc.sh" command-center
else
    exec python3 -c '
import socket
try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect("/tmp/carbon-shell.sock")
    s.sendall(b"command-center\n")
    s.close()
except Exception:
    pass
'
fi
