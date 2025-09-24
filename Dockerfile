FROM ubuntu:22.04

ARG CANN_VERSION=8.1.RC1
ARG TARGETPLATFORM
ARG TARGETARCH
ARG TARGETOS
ARG ASCEND_LINUX_ARCH=linux-aarch64

LABEL org.opencontainers.image.title="Ascend CANN Toolkit Image" \
   org.opencontainers.image.version="${CANN_VERSION}" \
   org.opencontainers.image.description="Ubuntu 22.04 + Python 3.9 + Ascend CANN toolkit ${CANN_VERSION}" \
   org.opencontainers.image.base.name="ubuntu:22.04" \
   org.opencontainers.image.architecture="${TARGETARCH}"

ENV DEBIAN_FRONTEND=noninteractive \
   ASCEND_CANN_VERSION=${CANN_VERSION} \
   ASCEND_LINUX_ARCH=${ASCEND_LINUX_ARCH}

# Install Python 3.9
RUN apt-get update \
   && apt-get install -y --no-install-recommends \
   software-properties-common \
   ca-certificates \
   curl \
   gnupg \
   && add-apt-repository ppa:deadsnakes/ppa -y \
   && apt-get update \
   && apt-get install -y --no-install-recommends \
   python3.9 \
   python3.9-distutils \
   python3.9-venv \
   # Install pip for Python 3.9
   && curl -sS https://bootstrap.pypa.io/get-pip.py -o get-pip.py \
   && python3.9 get-pip.py \
   && rm get-pip.py \
   # Clean up apt caches and optional build tools
   && apt-get purge -y --auto-remove software-properties-common \
   && rm -rf /var/lib/apt/lists/*

# Ensure user-installed Python scripts are on PATH
ENV PATH=/root/.local/bin:${PATH}

# Install required Python packages with --user
RUN python3.9 -m pip install --no-cache-dir \
   attrs \
   cython \
   numpy==1.24.0 \
   decorator \
   sympy \
   cffi \
   pyyaml \
   pathlib2 \
   psutil \
   protobuf==3.20 \
   scipy \
   requests \
   absl-py \
   --user

# Copy Ascend installers into image
COPY *.run /tmp/installers/

# Run toolkit installer, set env in profiles, then kernels, non-interactively
RUN set -e; \
   chmod +x /tmp/installers/*.run; \
   /tmp/installers/Ascend-cann-toolkit_8.1.RC1_linux-aarch64.run --install --quiet; \
   echo '[ -f /usr/local/Ascend/ascend-toolkit/set_env.sh ] && . /usr/local/Ascend/ascend-toolkit/set_env.sh' > /etc/profile.d/ascend-toolkit.sh; \
   chmod 644 /etc/profile.d/ascend-toolkit.sh; \
   echo 'if [ -f /usr/local/Ascend/ascend-toolkit/set_env.sh ]; then source /usr/local/Ascend/ascend-toolkit/set_env.sh; fi' >> /etc/profile; \
   echo 'if [ -f /usr/local/Ascend/ascend-toolkit/set_env.sh ]; then source /usr/local/Ascend/ascend-toolkit/set_env.sh; fi' >> /root/.bashrc; \
   /tmp/installers/Ascend-cann-kernels-*.run --install --quiet; \
   rm -f /tmp/installers/*.run

ENV BASH_ENV=/etc/profile.d/ascend-toolkit.sh

