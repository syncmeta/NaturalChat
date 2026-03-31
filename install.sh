#!/usr/bin/env bash
# Convenience wrapper — delegates to scripts/install.sh
exec "$(dirname "$0")/scripts/install.sh" "$@"
