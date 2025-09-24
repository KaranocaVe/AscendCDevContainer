# AscendCDevContainer

Template repo to build and publish Ascend CANN runtime images per version branch.

Quick start
- Create a version branch off main (template): e.g. `release/8.1.RC1`
- Edit `version.env` in that branch:
  - `CANN_VERSION` (e.g. 8.1.RC1)
  - `KERNEL_VARIANT` (e.g. 910b)
  - Optional `BASE_URL` (defaults to Huawei OBS CANN repo)
- Configure GitHub Actions secrets:
  - `DOCKERHUB_USERNAME`
  - `DOCKERHUB_TOKEN`
- Push to the branch. Workflow downloads installers, builds images, validates with `valid.sh`, pushes tags:
  - `<version-lower>-arm64`, `<version-lower>-arm64-YYYYMMDD`
  - `<version-lower>-x86_64`, `<version-lower>-x86_64-YYYYMMDD`
  - Multi-arch manifest: `<version-lower>`, `<version-lower>-YYYYMMDD`

Notes
- arm64 builds run on a self-hosted ARM64 runner; amd64 runs on `ubuntu-latest`.
- Dockerfile expects the two `.run` files present in build context; the workflow downloads them before build.
- `valid.sh` performs basic runtime checks inside the built image.

Local build (equivalent to Action)
- Prepare `version.env` (same as in branch): set `CANN_VERSION`, `KERNEL_VARIANT`, optional `BASE_URL`.
- Run:
  - `./build-local.sh` to build both arch images locally
  - `./build-local.sh --amd64` or `--arm64` to build single arch
  - `./build-local.sh --image-repo yourname/ascend-cann` to override repo
  - `./build-local.sh --push` to push both arch and create multi-arch manifest (requires `docker login`)
