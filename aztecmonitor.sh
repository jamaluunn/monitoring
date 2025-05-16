#!/bin/bash

REMOTE_RPC="https://aztec-rpc.cerberusnode.com"

# Telegram bot credentials (replace with your own)
TELEGRAM_BOT_TOKEN="7614647503:AAG_pDVvvgBrYhVIfTIoA4znbFsDXoYZwuE"
TELEGRAM_CHAT_ID="1115629210"

send_telegram_message() {
  local message="$1"
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d text="$message" \
    -d parse_mode="Markdown" > /dev/null
}

# Check if any app is running on port 8080
if lsof -i :8080 >/dev/null 2>&1; then
  echo "✅ Detected app running on port 8080"
  PORT=8080
else
  read -p "⚠️ No app found on port 8080. Please enter your local Aztec RPC port: " PORT
fi

LOCAL_RPC="http://localhost:$PORT"

while true; do
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "🔍 Checking Aztec node sync status at $timestamp"

  # Check LOCAL node status
  LOCAL_RESPONSE=$(curl -s -m 5 -X POST -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' "$LOCAL_RPC")

  if [ -z "$LOCAL_RESPONSE" ] || [[ "$LOCAL_RESPONSE" == *"error"* ]]; then
    echo "❌ Local node not responding or returned an error. Please check if it's running on $LOCAL_RPC"
    LOCAL="N/A"
    send_telegram_message "❌ *Local node error:* No response or error from local node at $LOCAL_RPC (Checked at $timestamp)"
  else
    LOCAL=$(echo "$LOCAL_RESPONSE" | jq -r ".result.proven.number")
  fi

  # Check REMOTE node status
  REMOTE_RESPONSE=$(curl -s -m 5 -X POST -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' "$REMOTE_RPC")

  if [ -z "$REMOTE_RESPONSE" ] || [[ "$REMOTE_RESPONSE" == *"error"* ]]; then
    echo "⚠️ Remote RPC ($REMOTE_RPC) not responding or returned an error."
    REMOTE="N/A"
    send_telegram_message "⚠️ *Remote node error:* No response or error from remote RPC at $REMOTE_RPC (Checked at $timestamp)"
  else
    REMOTE=$(echo "$REMOTE_RESPONSE" | jq -r ".result.proven.number")
  fi

  echo "🧱 Local block:  $LOCAL"
  echo "🌐 Remote block: $REMOTE"

  if [[ "$LOCAL" == "N/A" ]] || [[ "$REMOTE" == "N/A" ]]; then
    echo "🚫 Cannot determine sync status due to an error in one of the RPC responses."
  elif [ "$LOCAL" = "$REMOTE" ]; then
    echo "✅ Your node is fully synced!"
    send_telegram_message "✅ *Node Synced:* Your local node is fully synced at block $LOCAL (Checked at $timestamp)"
  else
    echo "⏳ Still syncing... ($LOCAL / $REMOTE)"
    send_telegram_message "⏳ *Syncing:* Your local node is syncing ($LOCAL / $REMOTE) (Checked at $timestamp)"
  fi

  echo "-------------------------------"
  sleep 10
done
