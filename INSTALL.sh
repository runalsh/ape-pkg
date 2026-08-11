#!/bin/bash
# Installation script for apepkg dependencies on Linux

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
fi

echo "Installing apepkg dependencies..."

# Detect OS
if [ -f /etc/debian_version ]; then
    OS="debian"
    echo "Detected Debian/Ubuntu system"
elif [ -f /etc/redhat-release ]; then
    OS="redhat"
    echo "Detected Red Hat/Fedora/CentOS system"
else
    echo "Unsupported operating system"
    exit 1
fi

# Install system dependencies
if [ "$OS" = "debian" ]; then
    echo "Installing build dependencies..."
    $SUDO apt-get update
    $SUDO apt-get install -y build-essential libssl-dev libz-dev libxml2-dev git autoconf automake libtool msitools wixl
elif [ "$OS" = "redhat" ]; then
    echo "Installing build dependencies..."
    set +e
    $SUDO dnf install -y oracle-epel-release-el8 2>/dev/null
    $SUDO dnf install -y oracle-epel-release-el9 2>/dev/null
    $SUDO dnf install -y oracle-epel-release-el10 2>/dev/null
    $SUDO dnf install -y epel-release 2>/dev/null
    set -e
    $SUDO dnf install -y gcc gcc-c++ make openssl-devel zlib-devel libxml2-devel git autoconf automake libtool msitools
fi

# Create temporary directory
TMPDIR=$(mktemp -d)
cd "$TMPDIR"

# Install bomutils
echo "Installing bomutils..."
git clone https://github.com/hogliux/bomutils.git
cd bomutils
make CXXFLAGS="-fPIC -O2"
$SUDO make install
cd ..

# Install xar
echo "Installing xar..."
git clone https://github.com/mackyle/xar.git
cd xar/xar
sed -i 's/OpenSSL_add_all_ciphers/EVP_get_cipherbyname/g' configure.ac
./autogen.sh
./configure ac_cv_lib_crypto_OpenSSL_add_all_ciphers=yes --prefix=/usr
make
$SUDO make install
cd ../..

# Install apepkg python script to /usr/bin/apepkg
$SUDO cp "$SCRIPT_DIR/apepkg" /usr/bin/apepkg
$SUDO chmod +x /usr/bin/apepkg

# Install rcodesign for package signing if missing
if ! command -v rcodesign &>/dev/null; then
    echo "Installing rcodesign..."
    ARCH_NAME="$(uname -m)"
    if [ "$ARCH_NAME" = "aarch64" ]; then
        RCODESIGN_URL="https://github.com/indygreg/apple-platform-rs/releases/download/apple-codesign/0.29.0/apple-codesign-0.29.0-aarch64-unknown-linux-musl.tar.gz"
    else
        RCODESIGN_URL="https://github.com/indygreg/apple-platform-rs/releases/download/apple-codesign/0.29.0/apple-codesign-0.29.0-x86_64-unknown-linux-musl.tar.gz"
    fi
    curl -sL "$RCODESIGN_URL" | tar -xz -C "$TMPDIR"
    $SUDO cp "$TMPDIR"/apple-codesign-*/rcodesign /usr/bin/rcodesign
    $SUDO chmod +x /usr/bin/rcodesign
fi

# Cleanup
cd - > /dev/null
rm -rf "$TMPDIR"

# Update library cache (Linux)
$SUDO ldconfig

echo ""
echo "Installation complete!"
echo ""
echo "Verify installation:"
echo "  which mkbom lsbom xar"
echo ""
echo "Optional: Install PyYAML for YAML build-info support:"
echo "  pip install PyYAML"
echo ""
echo "You can now use apepkg to build macOS packages on Linux."
