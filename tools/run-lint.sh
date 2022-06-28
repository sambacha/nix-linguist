#!/usr/bin/env bash
set -eEu -o pipefail
shopt -s extdebug

msg=$(xsltproc --xinclude $PATH_TO_XSLT_LINT_FILE $INPUT_PATH)
if [[ "" = "$msg" ]]; then
	exit 0
else
	echo $msg >&2
	exit 1
fi
