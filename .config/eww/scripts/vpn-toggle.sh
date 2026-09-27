#!/usr/bin/env bash
# Toggle the dev2-uat OpenVPN connection via NetworkManager.
# The server uses OpenVPN's static challenge, which NM-openvpn can't send, so the
# password goes out pre-encoded as SCRV1:base64(password):base64(code).
# The account password lives in the GNOME keyring; NM stores none (password-flags=2).

conn="dev2-uat-vpn"
keyring=(service dev2-uat-vpn account vpn)
state_dir="${XDG_RUNTIME_DIR:-/tmp}/eww-vpn"
mkdir -p "$state_dir"
chmod 700 "$state_dir"
log="$state_dir/nmcli.log"
connecting_flag="$state_dir/connecting"
pwfile="$state_dir/secrets"

active() {
  [ "$(nmcli -g GENERAL.STATE connection show "$conn" 2>/dev/null | head -1)" = "activated" ]
}

connect() {
  umask 077
  printf 'vpn.secrets.password:SCRV1:%s:%s\n' \
    "$(printf '%s' "$VPN_PASSWORD" | base64 -w0)" \
    "$(printf '%s' "$VPN_OTP" | base64 -w0)" > "$pwfile"

  # After AUTH_FAILED, NM asks for secrets again and nmcli re-answers from the
  # file, so one bad login repeats until the server locks the account.
  since="@$(date +%s)"
  (
    while sleep 0.5; do
      if journalctl -u NetworkManager --since "$since" -o cat 2>/dev/null | grep -q 'AUTH_FAILED'; then
        nmcli connection down "$conn" >/dev/null 2>&1
        exit
      fi
    done
  ) &
  watcher=$!

  nmcli connection up "$conn" passwd-file "$pwfile" > "$log" 2>&1
  rc=$?
  kill "$watcher" 2>/dev/null
  shred -u "$pwfile" 2>/dev/null || rm -f "$pwfile"
  rm -f "$connecting_flag"

  if [ $rc -eq 0 ]; then
    if [ "$VPN_STORE" = 1 ]; then
      printf '%s' "$VPN_PASSWORD" | secret-tool store --label="dev2-uat VPN" "${keyring[@]}"
    fi
    return
  fi

  journalctl -u NetworkManager --since "$since" -o short 2>/dev/null | grep nm-openvpn >> "$log"
  reason=$(grep -o 'AUTH_FAILED,.*' "$log" | head -1)
  hint=""
  if [ "$VPN_STORE" = 0 ] && [ -n "$reason" ]; then
    hint=" Password changed? secret-tool clear ${keyring[*]}"
  fi
  notify-send -u critical 'VPN' "${reason:-Connection failed.}${hint} (log: $log)"
}

if [ "${1:-}" = "--connect" ]; then
  connect
  exit
fi

# Already connected (or mid-connect) -> bring it down / cancel.
if active || [ -f "$connecting_flag" ]; then
  nmcli connection down "$conn" >/dev/null 2>&1
  rm -f "$connecting_flag"
  exit 0
fi

password=$(secret-tool lookup "${keyring[@]}" 2>/dev/null)
store=0
if [ -z "$password" ]; then
  password=$(zenity --password --title="dev2-uat VPN password" 2>/dev/null) || exit 0
  [ -n "$password" ] || exit 0
  store=1
fi

otp=$(zenity --entry --title="dev2-uat VPN" \
        --text="Enter your Authenticator code:" --width=280 2>/dev/null) || exit 0
otp=$(printf '%s' "$otp" | tr -cd '0-9')
if [ -z "$otp" ]; then
  notify-send -u critical "VPN" "No code entered, not connecting."
  exit 1
fi

# Mark connecting so the indicator updates immediately.
touch "$connecting_flag"
eww update "vpn-state=connecting" "vpn-tooltip=Connecting to VPN…" 2>/dev/null

# Connect detached so the eww button returns at once; the status poll takes over.
# Secrets travel in the environment, never in argv.
VPN_PASSWORD="$password" VPN_OTP="$otp" VPN_STORE="$store" \
  setsid -f "$0" --connect >/dev/null 2>&1
