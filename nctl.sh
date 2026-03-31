#!/usr/bin/env bash
# Convenience wrapper — delegates to scripts/nctl.sh
exec "$(dirname "$0")/scripts/nctl.sh" "$@"
