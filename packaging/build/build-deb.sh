#!/bin/bash
# Build DEB packages for Ubuntu/Debian

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGING_DIR="$PROJECT_ROOT/packaging"

# Default values
VERSION="${VERSION:-1.0.0}"
MAINTAINER="${MAINTAINER:-Linux Club of Peking University <linuxclub@pku.edu.cn>}"
HOMEPAGE="${HOMEPAGE:-https://clab.pku.edu.cn}"

# Build directory - support custom build path
BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/build/deb}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Create package structure
PACKAGE_NAME="clab-guest-tools_${VERSION}_all"
PACKAGE_DIR="$BUILD_DIR/$PACKAGE_NAME"
mkdir -p "$PACKAGE_DIR/DEBIAN"

# Generate control file
sed -e "s/{{VERSION}}/$VERSION/g" \
    -e "s/{{MAINTAINER}}/$MAINTAINER/g" \
    -e "s|{{HOMEPAGE}}|$HOMEPAGE|g" \
    "$PACKAGING_DIR/deb/control.template" > "$PACKAGE_DIR/DEBIAN/control"

# Copy maintainer scripts
cp "$PACKAGING_DIR/deb/postinst" "$PACKAGE_DIR/DEBIAN/"
cp "$PACKAGING_DIR/deb/prerm" "$PACKAGE_DIR/DEBIAN/"
chmod 755 "$PACKAGE_DIR/DEBIAN/postinst"
chmod 755 "$PACKAGE_DIR/DEBIAN/prerm"

# Source the DEB file generation functions
source "$PACKAGING_DIR/common/generate-deb-files.sh"

# Copy application files using common files list
copy_deb_files "$PACKAGING_DIR/common/files.list" "$PACKAGE_DIR" "$PROJECT_ROOT"

# Build package
cd "$BUILD_DIR"
dpkg-deb --build "clab-guest-tools_${VERSION}_all"

echo "DEB package built: $BUILD_DIR/clab-guest-tools_${VERSION}_all.deb"
