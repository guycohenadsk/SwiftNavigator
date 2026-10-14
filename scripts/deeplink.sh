#!/usr/bin/env bash
# Opens a deep link in the booted simulator.
#
#   scripts/deeplink.sh screenC                  → demoapp://screenC        (Screen C tab)
#   scripts/deeplink.sh issues <issue-uuid>      → demoapp://issues/<id>    (that issue)
#   scripts/deeplink.sh screenB | screenD | issues
#
# Set SIM to a device id to target a specific simulator (default: booted). iOS may ask
# "Open in TheNavigation?" the first time — tap Open.
set -euo pipefail
target=${1:?usage: deeplink.sh <issues|screenB|screenC|screenD> [id]}
url="demoapp://${target}${2:+/$2}"
echo "Opening $url"
xcrun simctl openurl "${SIM:-booted}" "$url"
