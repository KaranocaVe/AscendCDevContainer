#!/usr/bin/env bash
set -euo pipefail

# Local counterpart of the GitHub Actions workflow
# - Reads version.env
# - Downloads installers with spoofed headers
# - Builds per-arch images (amd64 via linux/amd64, arm64 via linux/arm64)
# - Optionally pushes and creates multi-arch manifest

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT_DIR"

if [[ ! -f version.env ]]; then
  echo "version.env missing" >&2; exit 1
fi
set -a; source version.env; set +a
: "${CANN_VERSION:?CANN_VERSION is required in version.env}"
: "${KERNEL_VARIANT:?KERNEL_VARIANT is required in version.env}"
: "${BASE_URL:=https://ascend-repo.obs.cn-east-2.myhuaweicloud.com/CANN}"

IMAGE_REPO=${IMAGE_REPO:-"${DOCKERHUB_USERNAME:-${USER}}/ascend-cann"}
DATE=$(date +%Y%m%d)
VERSION_LOWER=$(echo "$CANN_VERSION" | tr '[:upper:]' '[:lower:]')

download_with_headers() {
  local url="$1" out="$2"
  local UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36 Edg/140.0.0.0'
  curl -L --fail -o "$out" "$url" \
    -H 'Host: ascend-repo.obs.cn-east-2.myhuaweicloud.com' \
    -H 'Connection: keep-alive' \
    -H 'sec-ch-ua: "Chromium";v="140", "Not=A?Brand";v="24", "Microsoft Edge";v="140"' \
    -H 'sec-ch-ua-mobile: ?0' \
    -H 'sec-ch-ua-platform: "macOS"' \
    -H 'Upgrade-Insecure-Requests: 1' \
    -H "User-Agent: ${UA}" \
    -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' \
    -H 'Sec-Fetch-Site: cross-site' \
    -H 'Sec-Fetch-Mode: navigate' \
    -H 'Sec-Fetch-User: ?1' \
    -H 'Sec-Fetch-Dest: iframe' \
    -H 'Sec-Fetch-Storage-Access: active' \
    -H 'Referer: https://www.hiascend.com/' \
    -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-US;q=0.7,en-GB;q=0.6'
}

compute_urls() {
  local linux_arch="$1"
  local product_dir=$(printf 'CANN %s' "$CANN_VERSION" | sed 's/ /%20/g')
  TOOLKIT_FILE="Ascend-cann-toolkit_${CANN_VERSION}_${linux_arch}.run"
  KERNELS_FILE="Ascend-cann-kernels-${KERNEL_VARIANT}_${CANN_VERSION}_${linux_arch}.run"
  TOOLKIT_URL="${BASE_URL}/${product_dir}/${TOOLKIT_FILE}?response-content-type=application/octet-stream"
  KERNELS_URL="${BASE_URL}/${product_dir}/${KERNELS_FILE}?response-content-type=application/octet-stream"
}

build_arch() {
  local platform="$1" tag_suffix="$2" linux_arch="$3"
  compute_urls "$linux_arch"
  echo "==> Downloading installers for $linux_arch"
  download_with_headers "$KERNELS_URL" "$KERNELS_FILE"
  download_with_headers "$TOOLKIT_URL" "$TOOLKIT_FILE"

  echo "==> Building $platform"
  docker buildx build --platform "$platform" \
    -t "$IMAGE_REPO:${VERSION_LOWER}-${tag_suffix}" \
    -t "$IMAGE_REPO:${VERSION_LOWER}-${tag_suffix}-${DATE}" \
    --build-arg CANN_VERSION="$CANN_VERSION" \
    --load \
    .

  echo "==> Validating $platform"
  REPO="$IMAGE_REPO" TAG="${VERSION_LOWER}-${tag_suffix}" bash ./valid.sh
}

usage() {
  echo "Usage: $0 [--amd64] [--arm64] [--push]"
}

DO_PUSH=false
DO_AMD64=false
DO_ARM64=false
for a in "$@"; do
  case "$a" in
    --push) DO_PUSH=true ;;
    --amd64) DO_AMD64=true ;;
    --arm64) DO_ARM64=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $a" >&2; usage; exit 1 ;;
  esac
done
if ! $DO_AMD64 && ! $DO_ARM64; then DO_AMD64=true; DO_ARM64=true; fi

# Ensure buildx
docker buildx ls >/dev/null 2>&1 || docker buildx create --use

if $DO_AMD64; then
  build_arch linux/amd64 x86_64 linux-x86_64
fi
if $DO_ARM64; then
  build_arch linux/arm64 arm64 linux-aarch64
fi

if $DO_PUSH; then
  echo "==> Pushing images and creating manifest"
  docker login
  docker push "$IMAGE_REPO:${VERSION_LOWER}-x86_64"
  docker push "$IMAGE_REPO:${VERSION_LOWER}-x86_64-${DATE}"
  docker push "$IMAGE_REPO:${VERSION_LOWER}-arm64"
  docker push "$IMAGE_REPO:${VERSION_LOWER}-arm64-${DATE}"
  docker buildx imagetools create \
    -t "$IMAGE_REPO:${VERSION_LOWER}" \
    "$IMAGE_REPO:${VERSION_LOWER}-x86_64" \
    "$IMAGE_REPO:${VERSION_LOWER}-arm64"
  docker buildx imagetools create \
    -t "$IMAGE_REPO:${VERSION_LOWER}-${DATE}" \
    "$IMAGE_REPO:${VERSION_LOWER}-x86_64-${DATE}" \
    "$IMAGE_REPO:${VERSION_LOWER}-arm64-${DATE}"
fi

echo "Done."

