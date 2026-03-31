#!/usr/bin/env bash
# Convenience wrapper — delegates to scripts/uninstall.sh
exec "$(dirname "$0")/scripts/uninstall.sh" "$@"
