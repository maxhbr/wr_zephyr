#!/usr/bin/env bash

set -euo pipefail

main() {
	local mmd svg
	mmd="${1}"
	svg="${mmd%.mmd}.svg"

	if [[ ! -f $mmd ]]; then
		echo "ERROR: $mmd does not exist"
		exit 1
	fi

	echo "$mmd -> $svg"

	if [[ $# -eq 2 && $2 == "--check" ]]; then
		echo "check ..."
		local tmpsvg
		tmpsvg="$(mktemp --suffix=.svg)"
		trap 'rm -f "'"$tmpsvg"'"' EXIT
		$0 "$mmd" --once "$tmpsvg"
		if ! cmp -s "$tmpsvg" "$svg"; then
			echo "ERROR: $svg changed"
			exit 1
		fi
	elif [[ $# -ge 2 && $2 == "--once" ]]; then
		if [[ $# -eq 3 ]]; then
			svg="$3"
		fi
		mmdc -i "$mmd" -o "$svg" -t neutral -b white
		echo "... done"
	else
		echo "watch ..."
		echo "$mmd" | entr "$0" "$mmd" --once
	fi
}

main "$@"
