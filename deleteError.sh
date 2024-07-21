#!/bin/bash

# Check if a directory path is provided
if [ $# -eq 0 ]; then
    echo "Error: Please provide a directory path."
    echo "Usage: $0 /path/to/directory"
    exit 1
fi

# Check if the provided path is a directory
if [ ! -d "$1" ]; then
    echo "Error: The specified path is not a valid directory."
    exit 1
fi

# Function to delete PNG and TXT files
delete_files() {
    local dir="$1"
    local btr_count=0
    
    # Use find to locate and delete BTR files
    while IFS= read -r -d '' file; do
        rm "$file"
        echo "Deleted: $file"
        ((btr_count++))
    done < <(find "$dir" -type f -iname "*.btr" -print0)

    echo "Total BTR files deleted: $btr_count"
}

# Call the function with the provided directory
delete_files "$1"