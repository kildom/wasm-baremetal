#!/bin/bash
set -e -o pipefail
"$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/scripts/build.sh" $@
