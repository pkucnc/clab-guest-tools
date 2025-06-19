#!/bin/bash
# Generate DEB package files from files.list

copy_deb_files() {
    local files_list="$1"
    local package_dir="$2"
    local project_root="$3"
    
    echo "Copying application files from files.list..."
    
    # Create directories first
    while IFS=':' read -r source dest perms type; do
        # Skip comments and empty lines
        [[ "$source" =~ ^#.*$ ]] || [[ -z "$source" ]] && continue
        
        if [[ "$type" == "dir" ]]; then
            mkdir -p "$package_dir$dest"
            chmod "$perms" "$package_dir$dest"
        elif [[ "$type" == "file" ]]; then
            # Create parent directory
            parent_dir=$(dirname "$dest")
            mkdir -p "$package_dir$parent_dir"
        fi
    done < "$files_list"
    
    # Copy files
    while IFS=':' read -r source dest perms type; do
        # Skip comments, empty lines, and directories
        [[ "$source" =~ ^#.*$ ]] || [[ -z "$source" ]] || [[ "$type" == "dir" ]] && continue
        
        if [[ -f "$project_root/$source" ]]; then
            cp "$project_root/$source" "$package_dir$dest"
            chmod "$perms" "$package_dir$dest"
            echo "  $source -> $dest (permissions: $perms)"
        else
            echo "Warning: Source file $project_root/$source not found"
        fi
    done < "$files_list"
    
    echo "Application files copied successfully."
}
