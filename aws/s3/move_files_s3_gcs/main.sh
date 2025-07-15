#!/bin/bash

# Exit on error (-e), unset variables (-u), and failures in pipelines (-o pipefail)
set -euo pipefail

echo "[INFO] Starting script execution..."

# -------------------------------------------
# CONFIGURATION SECTION
# -------------------------------------------

# Set the number of parallel processes (default: 10)
PARALLEL_JOBS=${PARALLEL_JOBS:-10}

# S3 bucket name where the source files are stored
SOURCE_S3_BUCKET="corp-app-prod-slingdata-exports"

# Folder inside the S3 bucket (must be provided via environment variable)
SOURCE_S3_FOLDER=${SOURCE_FOLDER:-}

# Validate the folder input
if [[ -z "$SOURCE_S3_FOLDER" ]]; then
    echo "[ERROR] SOURCE_FOLDER environment variable is not set."
    exit 1
fi

# GCS destination bucket and folder
DESTINATION_GCS_BUCKET="corp-lakehouse"
DESTINATION_GCS_FOLDER="databases/bronze"

# Display the configuration being used
echo "[INFO] Source S3 bucket: $SOURCE_S3_BUCKET"
echo "[INFO] Source S3 folder: $SOURCE_S3_FOLDER"
echo "[INFO] Destination GCS bucket: $DESTINATION_GCS_BUCKET"
echo "[INFO] Destination GCS folder: $DESTINATION_GCS_FOLDER"
echo "[INFO] Parallel jobs: $PARALLEL_JOBS"

# -------------------------------------------
# FIND UNIQUE SUBFOLDERS IN S3
# -------------------------------------------

echo "[INFO] Retrieving list of unique subfolders in S3..."

# List all files in the S3 folder recursively
# Extract just the folder structure (excluding file names)
# Remove duplicates using `sort -u`
UNIQUE_SUBFOLDERS=$(aws s3 ls "s3://$SOURCE_S3_BUCKET/$SOURCE_S3_FOLDER/" --recursive | 
    awk '{print $4}' | awk -F'/' '{OFS="/"; $NF=""; print $0}' | sort -u)

# If no folders found, exit with warning
if [[ -z "$UNIQUE_SUBFOLDERS" ]]; then
    echo "[WARNING] No subfolders found in S3 source path."
    exit 1
fi

# Display the list of folders that will be processed
echo "[INFO] Unique subfolders found:"
echo "$UNIQUE_SUBFOLDERS"

# -------------------------------------------
# FUNCTION: Copy the latest file from a given S3 subfolder to GCS
# -------------------------------------------

copy_latest_s3_to_gcs() {
    local subfolder_path="$1"
    echo "[INFO][$$] Processing subfolder: $subfolder_path"

    # List files inside this subfolder, sort by date (newest first), take the top one
    LATEST_FILE_PATH=$(aws s3 ls "s3://$SOURCE_S3_BUCKET/$subfolder_path" --recursive | 
        sort -r | head -n 1 | awk '{print $4}')

    # If a file was found
    if [[ -n "$LATEST_FILE_PATH" ]]; then
        FILE_NAME="data.parquet"  # Rename file on GCS side
        DEST_PATH="gs://$DESTINATION_GCS_BUCKET/$DESTINATION_GCS_FOLDER/$subfolder_path$FILE_NAME"
        echo "[INFO][$$] Latest file: $LATEST_FILE_PATH --> Destination: $DEST_PATH"

        # Attempt to copy file from S3 to GCS using gsutil
        if ! gsutil cp "s3://$SOURCE_S3_BUCKET/$LATEST_FILE_PATH" "$DEST_PATH"; then
            echo "[ERROR][$$] Failed to copy $LATEST_FILE_PATH -> $DEST_PATH"
            exit 1
        else
            echo "[SUCCESS][$$] Successfully copied $LATEST_FILE_PATH -> $DEST_PATH"
        fi
    else
        echo "[WARNING][$$] No files found in: $subfolder_path"
    fi
}

# Export the function and environment variables for use in parallel processes
export -f copy_latest_s3_to_gcs
export SOURCE_S3_BUCKET DESTINATION_GCS_BUCKET DESTINATION_GCS_FOLDER

# -------------------------------------------
# PARALLEL EXECUTION SECTION
# -------------------------------------------

echo "[INFO] Starting parallel copy operations..."

# For each subfolder, call the copy function in parallel
# -P defines the number of parallel jobs
# `bash -c` allows calling the function in a subshell
echo "$UNIQUE_SUBFOLDERS" | xargs -P "$PARALLEL_JOBS" -I {} bash -c 'copy_latest_s3_to_gcs "$@"' _ {} || {
    echo "[ERROR] One or more copy operations failed."
    exit 1
}

echo "[INFO] Script execution completed successfully."
