#!/usr/bin/env bash

exec  nix run .#west -- "$@"