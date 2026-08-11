#!/bin/bash
# Installation script for apepkg dependencies on Linux

set -e

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
    $SUDO dnf install -y oracle-epel-release-el8 oracle-epel-release-el9 oracle-epel-release-el10 epel-release 2>/dev/null || true
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
./autogen.sh
./configure ac_cv_lib_crypto_OpenSSL_add_all_ciphers=yes --prefix=/usr
make
$SUDO make install
cd ../..

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
