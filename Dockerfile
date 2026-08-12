FROM ubuntu:24.04

LABEL description="Ubuntu 24.04 Docker image for building and signing macOS .pkg installer packages on Linux via apepkg & rcodesign"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Install build dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        build-essential \
        autoconf \
        automake \
        libtool \
        libssl-dev \
        zlib1g-dev \
        libxml2-dev \
        python3 \
        python3-pip \
        curl \
        file \
        cpio \
        git \
        openssl \
        ca-certificates \
        tar \
        gzip \
    && rm -rf /var/lib/apt/lists/*

# Install rcodesign binary directly
RUN ARCH="$(uname -m)" && \
    if [ "$ARCH" = "aarch64" ]; then RCODESIGN_ARCH="aarch64-unknown-linux-musl"; else RCODESIGN_ARCH="x86_64-unknown-linux-musl"; fi && \
    RCODESIGN_URL=$(curl -s https://api.github.com/repos/indygreg/apple-platform-rs/releases/latest | grep "browser_download_url" | grep "${RCODESIGN_ARCH}.tar.gz" | head -n1 | cut -d '"' -f 4) && \
    if [ -z "$RCODESIGN_URL" ]; then RCODESIGN_URL="https://github.com/indygreg/apple-platform-rs/releases/download/apple-codesign%2F0.33.0/apple-codesign-0.33.0-${RCODESIGN_ARCH}.tar.gz"; fi && \
    curl -sL "$RCODESIGN_URL" | tar -xz -C /tmp && \
    cp /tmp/apple-codesign-*/rcodesign /usr/bin/rcodesign && \
    chmod +x /usr/bin/rcodesign && \
    rm -rf /tmp/apple-codesign*

# Copy ape-pkg source code
WORKDIR /tmp/ape-pkg
COPY . /tmp/ape-pkg

# Install apepkg, bomutils (mkbom/lsbom), and xar
RUN ./INSTALL.sh && \
    rm -rf /tmp/ape-pkg

# Verify all required binaries are pre-installed
RUN which apepkg rcodesign xar mkbom lsbom && \
    apepkg --version && \
    rcodesign --version

WORKDIR /workspace

CMD ["apepkg", "--help"]
