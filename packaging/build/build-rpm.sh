#!/bin/bash
# Build RPM packages for Rocky Linux/CentOS/RHEL

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGING_DIR="$PROJECT_ROOT/packaging"

# Default values
VERSION="${VERSION:-1.0.0}"
MAINTAINER="${MAINTAINER:-Linux Club of Peking University <linuxclub@pku.edu.cn>}"
HOMEPAGE="${HOMEPAGE:-https://git.pku.edu.cn/lcpu/clab-guest-tools}"
LICENSE="${LICENSE:-MIT}"

# Build directory
BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/build/rpm}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

# Create source tarball - include entire project except build and git directories
TARBALL_NAME="clab-guest-tools-${VERSION}.tar.gz"
cd "$PROJECT_ROOT"
tar --exclude='build' --exclude='.git' --exclude='.gitignore' \
    --exclude='*.deb' --exclude='*.rpm' --exclude='*.tar.gz' \
    -czf "$BUILD_DIR/SOURCES/$TARBALL_NAME" \
    --transform "s,^,clab-guest-tools-${VERSION}/," \
    .

# Source the RPM section generation functions
source "$PACKAGING_DIR/common/generate-rpm-sections.sh"

# Generate install and files sections from files.list
INSTALL_SECTION=$(generate_rpm_install_section "$PACKAGING_DIR/common/files.list")
FILES_SECTION=$(generate_rpm_files_section "$PACKAGING_DIR/common/files.list")

# Generate spec file with dynamic sections
sed -e "s/{{VERSION}}/$VERSION/g" \
    -e "s/{{MAINTAINER}}/$MAINTAINER/g" \
    -e "s|{{HOMEPAGE}}|$HOMEPAGE|g" \
    -e "s/{{LICENSE}}/$LICENSE/g" \
    -e "s/{{DATE}}/$(date +'%a %b %d %Y')/g" \
    "$PACKAGING_DIR/rpm/spec.template" > "$BUILD_DIR/SPECS/clab-guest-tools.spec.tmp"

# Replace the install and files sections
awk -v install_section="$INSTALL_SECTION" -v files_section="$FILES_SECTION" '
/^%install/ {
    print $0
    print install_section
    # Skip until next section
    while (getline && !/^%/) continue
    if (/^%/) print $0
    next
}
/^%files/ {
    print $0
    print files_section
    # Skip until next section or end
    while (getline && !/^%/) continue
    if (/^%/) print $0
    next
}
{ print }
' "$BUILD_DIR/SPECS/clab-guest-tools.spec.tmp" > "$BUILD_DIR/SPECS/clab-guest-tools.spec"

rm "$BUILD_DIR/SPECS/clab-guest-tools.spec.tmp"

# Build RPM
rpmbuild --define "_topdir $BUILD_DIR" \
         --define "_rpmdir $BUILD_DIR/RPMS" \
         --define "_srcrpmdir $BUILD_DIR/SRPMS" \
         -ba "$BUILD_DIR/SPECS/clab-guest-tools.spec"

echo "RPM packages built:"
find "$BUILD_DIR/RPMS" -name "*.rpm" -type f
find "$BUILD_DIR/SRPMS" -name "*.rpm" -type f
