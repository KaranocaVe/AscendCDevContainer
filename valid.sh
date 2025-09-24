#!/usr/bin/env bash
set -euo pipefail

: "${REPO:?REPO is required}"
: "${TAG:?TAG is required}"

docker run --rm "$REPO:$TAG" bash -lc '
set -euo pipefail
echo "ARCH: $(uname -m)"
echo "CANN_VERSION: ${ASCEND_CANN_VERSION:-}"

# Basic env and installation checks
test -n "${ASCEND_CANN_VERSION:-}"
test -f /usr/local/Ascend/ascend-toolkit/set_env.sh
test -d /usr/local/Ascend/ascend-toolkit

# Python 3.9 and key packages
python3.9 -V
python3.9 - <<"PY"
import sys
print("pyver", sys.version.split()[0])
import numpy
print("numpy", numpy.__version__)
from google import protobuf
print("protobuf", protobuf.__version__)
PY
'