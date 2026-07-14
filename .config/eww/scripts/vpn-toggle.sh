#!/usr/bin/env bash
# Toggle the dev2-uat OpenVPN connection via NetworkManager.
# The account password is saved in NM; only the MFA one-time code is asked each
# time we connect (Google Authenticator / Authy).

conn="dev2-uat-vpn"
state_dir="${XDG_RUNTIME_DIR:-/tmp}/eww-vpn"
mkdir -p "$state_dir"
chmod 700 "$state_dir"
log="$state_dir/nmcli.log"
connecting_flag="$state_dir/connecting"
pwfile="$state_dir/otp"

active() {
  [ "$(nmcli -g GENERAL.STATE connection show "$conn" 2>/dev/null | head -1)" = "activated" ]
}

# Already connected (or mid-connect) -> bring it down / cancel.
if active || [ -f "$connecting_flag" ]; then
  nmcli connection down "$conn" >/dev/null 2>&1
  rm -f "$connecting_flag" "$pwfile"
  exit 0
fi

# Ask for the current MFA code.
otp=$(zenity --entry --title="dev2-uat VPN" \
        --text="Enter your Authenticator code:" --width=280 2>/dev/null) || exit 0
otp=$(printf '%s' "$otp" | tr -cd '0-9')
if [ -z "$otp" ]; then
  notify-send -u critical "VPN" "No code entered — not connecting."
  exit 1
fi

# The account password is saved in NM, so --ask only needs the one-time code,
# which we feed on stdin (this answers OpenVPN's dynamic MFA challenge).
umask 077
printf '%s\n' "$otp" > "$pwfile"

# Mark connecting so the indicator updates immediately.
touch "$connecting_flag"
eww update "vpn-state=connecting" "vpn-tooltip=Connecting to VPN…" 2>/dev/null

# Connect detached so the eww button returns at once; the status poll takes over.
setsid -f bash -c "
  nmcli --ask connection up '$conn' < '$pwfile' > '$log' 2>&1
  rc=\$?
  shred -u '$pwfile' 2>/dev/null || rm -f '$pwfile'
  rm -f '$connecting_flag'
  if [ \$rc -ne 0 ]; then
    notify-send -u critical 'VPN' 'Connection failed. See $log'
  fi
" >/dev/null 2>&1 &
