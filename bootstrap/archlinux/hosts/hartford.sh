if systemctl is-active --quiet tailscaled.service; then
  tailscale set --accept-routes=true --accept-dns=true

  if tailscale status --json | jq -e '.BackendState == "NeedsLogin"' >/dev/null; then
    log "Tailscale needs browser sign-in. After bootstrap, run:"
    log "  sudo tailscale up --accept-routes=true --accept-dns=true"
  fi
else
  log "skipping Tailscale preferences: tailscaled.service is not active"
fi

queue="hp-laserjet"
serial="VND5J38873"

usermod -aG lp "$BOOTSTRAP_USER"

if lpstat -v 2>/dev/null | grep -Fq "serial=$serial"; then
  log "Printer with serial '$serial' already configured, skipping."
else
  hp-setup -i -a -x --printer="$queue" "$serial" || log "[ERROR] hp-setup failed to setup '$queue'"
fi
