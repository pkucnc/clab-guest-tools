#!/bin/bash
# Test build script to verify files.list functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGING_DIR="$PROJECT_ROOT/packaging"

echo "=== CLab Guest Tools Packaging Test ==="
echo "Project Root: $PROJECT_ROOT"
echo "Packaging Dir: $PACKAGING_DIR"
echo

# Test 1: Verify files.list exists and is readable
echo "1. Testing files.list..."
FILES_LIST="$PACKAGING_DIR/common/files.list"
if [[ -f "$FILES_LIST" ]]; then
    echo "✓ files.list found: $FILES_LIST"
    echo "  File count: $(grep -v '^#' "$FILES_LIST" | grep -v '^$' | wc -l) entries"
else
    echo "✗ files.list not found!"
    exit 1
fi
echo

# Test 2: Parse and display files.list content
echo "2. Parsing files.list content..."
echo "Format: source_path -> destination_path (permissions, type)"
while IFS=':' read -r source dest perms type; do
    # Skip comments and empty lines
    [[ "$source" =~ ^#.*$ ]] || [[ -z "$source" ]] && continue
    
    if [[ "$type" == "file" ]]; then
        if [[ -f "$PROJECT_ROOT/$source" ]]; then
            status="✓"
        else
            status="✗ (missing)"
        fi
        echo "  $status $source -> $dest ($perms, $type)"
    elif [[ "$type" == "dir" ]]; then
        echo "  📁 $dest ($perms, $type)"
    fi
done < "$FILES_LIST"
echo

# Test 3: Test RPM section generation
echo "3. Testing RPM section generation..."
if [[ -f "$PACKAGING_DIR/common/generate-rpm-sections.sh" ]]; then
    echo "✓ RPM section generator found"
    source "$PACKAGING_DIR/common/generate-rpm-sections.sh"
    
    echo "--- Generated RPM %install section ---"
    generate_rpm_install_section "$FILES_LIST"
    echo
    
    echo "--- Generated RPM %files section ---"
    generate_rpm_files_section "$FILES_LIST"
    echo
else
    echo "✗ RPM section generator not found!"
fi

# Test 4: Test DEB file copying (dry run)
echo "4. Testing DEB file copying (dry run)..."
if [[ -f "$PACKAGING_DIR/common/generate-deb-files.sh" ]]; then
    echo "✓ DEB file generator found"
    
    # Create a temporary test directory
    TEST_DIR="/tmp/clab-test-$$"
    mkdir -p "$TEST_DIR"
    
    echo "  Testing file copying to: $TEST_DIR"
    
    # Source the function but modify it for dry run
    source "$PACKAGING_DIR/common/generate-deb-files.sh"
    
    # Override the copy function for dry run
    copy_deb_files_dry_run() {
        local files_list="$1"
        local package_dir="$2"
        local project_root="$3"
        
        echo "  Dry run - would copy files to: $package_dir"
        
        while IFS=':' read -r source dest perms type; do
            [[ "$source" =~ ^#.*$ ]] || [[ -z "$source" ]] || [[ "$type" == "dir" ]] && continue
            
            if [[ -f "$project_root/$source" ]]; then
                echo "    ✓ $source -> $dest ($perms)"
            else
                echo "    ✗ $source -> $dest ($perms) - source missing"
            fi
        done < "$files_list"
    }
    
    copy_deb_files_dry_run "$FILES_LIST" "$TEST_DIR" "$PROJECT_ROOT"
    
    # Clean up
    rm -rf "$TEST_DIR"
else
    echo "✗ DEB file generator not found!"
fi
echo

# Test 5: Verify all source files exist
echo "5. Verifying source files exist..."
missing_files=0
while IFS=':' read -r source dest perms type; do
    [[ "$source" =~ ^#.*$ ]] || [[ -z "$source" ]] || [[ "$type" == "dir" ]] && continue
    
    if [[ -f "$PROJECT_ROOT/$source" ]]; then
        echo "  ✓ $source"
    else
        echo "  ✗ $source (missing)"
        ((missing_files++))
    fi
done < "$FILES_LIST"

if [[ $missing_files -eq 0 ]]; then
    echo "✓ All source files found"
else
    echo "✗ $missing_files source files missing"
fi
echo

# Test 6: Check build script dependencies
echo "6. Checking build script dependencies..."
for script in "build-deb.sh" "build-rpm.sh"; do
    if [[ -f "$PACKAGING_DIR/build/$script" ]]; then
        echo "  ✓ $script found"
        if [[ -x "$PACKAGING_DIR/build/$script" ]]; then
            echo "    ✓ executable"
        else
            echo "    ⚠ not executable (run: chmod +x $PACKAGING_DIR/build/$script)"
        fi
    else
        echo "  ✗ $script not found"
    fi
done
echo

# Summary
echo "=== Test Summary ==="
if [[ $missing_files -eq 0 ]]; then
    echo "✓ All tests passed - packaging configuration looks good!"
    echo "  You can now run:"
    echo "    ./packaging/build/build-deb.sh"
    echo "    ./packaging/build/build-rpm.sh"
else
    echo "⚠ Some issues found - please fix missing files before building packages"
fi
