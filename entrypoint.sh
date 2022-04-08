#!/bin/bash
set -e

whirlpool_options=(
  --cli.torConfig.executable=/usr/local/bin/tor
)

WHIRLPOOL_BITCOIN_NETWORK=$(printf '%s\n' "$WHIRLPOOL_BITCOIN_NETWORK" | awk '{ print toupper($0) }')

if [ "$WHIRLPOOL_BITCOIN_NETWORK" == "TESTNET" ]; then
  whirlpool_options+=(--cli.server="TESTNET")
else
  whirlpool_options+=(--cli.server="MAINNET")
fi

if [ "$WHIRLPOOL_DOJO" == "on" ]; then
  if [[ -z WHIRLPOOL_DOJO_IP ]]; then
    echo "Error: WHIRLPOOL_DOJO_IP is undefined."
    exit 1
  fi

  whirlpool_options+=(--cli.dojo.enabled=true)

  if [ "$WHIRLPOOL_BITCOIN_NETWORK" == "TESTNET" ]; then
    whirlpool_options+=(--cli.dojo.url="http://$WHIRLPOOL_DOJO_IP:80/test/v2/")
  else
    whirlpool_options+=(--cli.dojo.url="http://$WHIRLPOOL_DOJO_IP:80/v2/")
  fi
fi

cd /home/whirlpool/.whirlpool-cli
java -jar /usr/local/whirlpool-cli/whirlpool-client-cli-run.jar "$@ ${whirlpool_options[@]}"
