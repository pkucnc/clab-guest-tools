#!/bin/bash
# Generate RPM spec sections from files.list

generate_rpm_install_section() {
    local files_list="$1"
    
    echo "rm -rf \$RPM_BUILD_ROOT"
    echo ""
    
    # Generate directory creation commands
    while IFS=':' read -r source dest perms type; do
        # Skip comments and empty lines
        [[ "$source" =~ ^#.*$ ]] || [[ -z "$source" ]] && continue
        
        if [[ "$type" == "dir" ]]; then
            echo "mkdir -p \$RPM_BUILD_ROOT$dest"
        elif [[ "$type" == "file" ]]; then
            # Create parent directory
            parent_dir=$(dirname "$dest")
            echo "mkdir -p \$RPM_BUILD_ROOT$parent_dir"
        fi
    done < "$files_list" | sort -u
    
    echo ""
    
    # Generate install commands
    while IFS=':' read -r source dest perms type; do
        # Skip comments, empty lines, and directories
        [[ "$source" =~ ^#.*$ ]] || [[ -z "$source" ]] || [[ "$type" == "dir" ]] && continue
        
        echo "install -m $perms $source \$RPM_BUILD_ROOT$dest"
    done < "$files_list"
}

generate_rpm_files_section() {
    local files_list="$1"
    
    echo "%defattr(-,root,root,-)"
    
    # Generate files list
    while IFS=':' read -r source dest perms type; do
        # Skip comments and empty lines
        [[ "$source" =~ ^#.*$ ]] || [[ -z "$source" ]] && continue
        
        if [[ "$type" == "file" ]]; then
            echo "$dest"
        elif [[ "$type" == "dir" ]]; then
            echo "%dir $dest"
        fi
    done < "$files_list"
}
