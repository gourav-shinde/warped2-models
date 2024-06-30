#!/bin/bash
# Allows batch runs of simulations for all folders in the config directory.
# Saves results to log files and moves them to a new directory after completion.

config_dir="config"

if [ ! -d "$config_dir" ]; then
    echo "Config directory does not exist: $config_dir"
    exit 1
fi

# Base directory where logs will be moved after completion
output_base_dir="completed_logs"
mkdir -p "$output_base_dir"

for folder in "$config_dir"/* ; do
    if [ -d "$folder" ]; then
        folder_name=$(basename "$folder")
        log_dir="logs/$folder_name"
        mkdir -p "$log_dir"

        echo "Processing folder: $folder_name"
        for config in "$folder"/* ; do
            echo "Running simulation for $config"
            log_file="$log_dir/$(basename "$config").log"
            ./configSimulate.sh "$config"
        done

        # Create a new directory to move the log files after completing the simulations
        timestamp=$(date +%Y%m%d%H%M%S)
        output_dir="$output_base_dir/${folder_name}_$timestamp"
        mkdir -p "$output_dir"
        mv "$log_dir"/* "$output_dir/"
        rmdir "$log_dir"
        echo "Logs moved to $output_dir"
    fi
done
