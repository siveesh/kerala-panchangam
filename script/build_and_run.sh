#!/usr/bin/env bash
set -euo pipefail

swift build
swift run "Malayalam Panchangam Calendar"
