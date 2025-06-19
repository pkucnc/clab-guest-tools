# CLab Guest Tools Packaging

This directory contains packaging configurations and build scripts for creating DEB and RPM packages of CLab Guest Tools.

## File Structure

```
packaging/
├── common/
│   ├── files.list                    # Common file list for both DEB and RPM
│   ├── generate-deb-files.sh         # DEB file copying functions
│   └── generate-rpm-sections.sh      # RPM spec section generation functions
├── deb/
│   ├── control.template              # DEB package control file template
│   ├── postinst                      # Post-installation script
│   └── prerm                         # Pre-removal script
├── rpm/
│   └── spec.template                 # RPM spec file template
└── build/
    ├── build-deb.sh                  # DEB package build script
    ├── build-rpm.sh                  # RPM package build script
    └── test-build.sh                 # Test build script
```

## Common File Management

Both DEB and RPM builds use a common file list (`packaging/common/files.list`) to manage which files are included in the packages. This ensures consistency between package formats.

### File List Format

```
# Format: source_path:destination_path:permissions:type
# Types: file, dir
# Permissions: 755 for executables, 644 for regular files, 755 for directories

clabcli:/usr/bin/clabcli:755:file
notify/clab-notify.sh:/usr/bin/clab-notify:755:file
shadowdesk/shadowdesk.env.default:/usr/share/clab/shadowdesk/shadowdesk.env.default:644:file
```

## Building Packages

### DEB Packages (Ubuntu/Debian)

```bash
# Build with default settings
./packaging/build/build-deb.sh

# Build with custom build directory
BUILD_DIR=/tmp/my-build ./packaging/build/build-deb.sh

```

### RPM Packages (Rocky Linux/CentOS/RHEL)

```bash
# Build with default settings
./packaging/build/build-rpm.sh

# Build with custom build directory
BUILD_DIR=/tmp/my-build ./packaging/build/build-rpm.sh
```

## Environment Variables

Both build scripts support the following environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `VERSION` | `1.0.0` | Package version |
| `MAINTAINER` | `Linux Club of Peking University <linuxclub@pku.edu.cn>` | Package maintainer |
| `HOMEPAGE` | `https://clab.pku.edu.cn` (DEB) / `https://git.pku.edu.cn/lcpu/clab-guest-tools` (RPM) | Project homepage |
| `LICENSE` | `MIT` | License (RPM only) |
| `BUILD_DIR` | `$PROJECT_ROOT/build/deb` or `$PROJECT_ROOT/build/rpm` | Build output directory |

## Adding New Files

To add new files to the packages:

1. Add the file mapping to `packaging/common/files.list`
2. The file will automatically be included in both DEB and RPM packages
3. No need to modify the build scripts

Example:
```
# Add a new configuration file
config/my-config.conf:/etc/clab/my-config.conf:644:file
```

## Testing

Use the test build script to verify both package formats:

```bash
./packaging/build/test-build.sh
```

This will build both DEB and RPM packages and display their contents for verification.
