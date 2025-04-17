#!/bin/bash

# ======================= USER CONFIG SECTION =======================
# Change these variables to match your setup

# Basic configuration
FILENAME="output.txt"           # Change to 'snapraid.conf' for production
DEST_DIR="$(pwd)"               # Change to '/etc' for production
TMP_SCRIPT="/tmp/snapraid_gen.sh"  # Location for temporary script
TMUX_SESSION="snapraider"

# Media root directory - base path for all media
MEDIA_ROOT="/var/lib/emby/media"  # Change this to your media root directory

# Content file settings
CONTENT_FILE_PER_DRIVE=true     # If true, creates a content file on each data drive for redundancy
RELATIVE_PATH_PER_DRIVE="."     # Relative path within each drive for content files (e.g., "." for root, "snapraid" for subdirectory)
PRIMARY_CONTENT_PATH="/var/snapraid.content"  # Path for the primary content file

# Define your pool categories and paths
# Format: "Category Name:prefix:/path/relative/to/media/root"
# Each line defines one category, with a friendly name, the prefix for data disks, and subdirectory
POOL_DEFINITIONS=(
    "Parity Drives:parity:parity"
    "TV Mount points:tv:tvshows"
    "Movies Mount points:movies:movies"
    "Documentaries Mount points:docs:documentaries"
    "Other Mount points:other:other"
    # Add more categories here as needed
    # Example: "Music Library:music:music"
)

# HDD pattern to search for in each directory
# This is the naming pattern for your hard drive directories
HDD_PATTERN="HDD*"

# Snapraid configuration options
SYNC_AFTER_GENERATION=false    # Set to true to execute snapraid sync after config generation
CHECK_DATE=true                # Check modification dates before generating new config - 'false' always generates a new config
EXIT_TMUX=true                 # If true, tmux session closes after completion
AUTOSAVE_GB=500                # Automatically save state when syncing after this many GB
BLOCKSIZE=256                  # Block size in KB

# File/directory exclusion patterns
EXCLUSION_PATTERNS=(
    "*.tmp"
    "/lost+found/"
    ".DS_Store"
    "/var/lib/emby/media/*/000*"
    "*.partial"
    "*.dbf"
    ".Trash*/"
    "*.unrecoverable"
    # Add more exclusion patterns here as needed
)

# Advanced options
NOHIDDEN=true                  # Whether to use the nohidden option
# ===================== END USER CONFIG SECTION =====================

# Set the full output path
OUTPUT="${DEST_DIR}/${FILENAME}"

# If date-checking is enabled, inspect each HDD* directory's modification time.
if [ "$CHECK_DATE" = true ]; then
    # Initialize to zero; this will hold the latest modification timestamp found.
    latest_mod=0
    
    # Check each pool directory for modifications
    for pool_def in "${POOL_DEFINITIONS[@]}"; do
        # Parse the pool definition
        category=$(echo "$pool_def" | cut -d ':' -f1)
        prefix=$(echo "$pool_def" | cut -d ':' -f2)
        rel_path=$(echo "$pool_def" | cut -d ':' -f3)
        base_path="${MEDIA_ROOT}/${rel_path}"
        
        echo "[*] Checking for modifications in: $base_path"
        
        # Check each HDD directory for this pool
        for dir in "$base_path"/$HDD_PATTERN; do
            if [ -d "$dir" ]; then
                mod=$(stat -c %Y "$dir")
                if [ "$mod" -gt "$latest_mod" ]; then
                    latest_mod=$mod
                    echo "[*] Found newer modification in: $dir ($(date -d @$mod))"
                fi
            fi
        done
    done

    # If no HDD directories were found, proceed with generation.
    if [ "$latest_mod" -eq 0 ]; then
        echo "[*] No HDD directories found for date check; proceeding with config generation."
    elif [ -f "$OUTPUT" ]; then
        config_mod=$(stat -c %Y "$OUTPUT")
        if [ "$config_mod" -ge "$latest_mod" ]; then
            echo "[*] No new modifications detected in HDD directories; skipping config generation."
            if [ "$SYNC_AFTER_GENERATION" = true ]; then
                echo "[*] Running snapraid sync command using existing configuration file..."
                snapraid -c "$OUTPUT" sync
                echo "[+] SnapRAID sync completed."
            fi
            exit 0
        else
            echo "[*] Detected newer modifications since last config generation ($(date -d @$latest_mod))."
        fi
    fi
fi

# Kill existing tmux session if it exists.
if tmux has-session -t "$TMUX_SESSION" &>/dev/null; then
    echo "[*] Killing previous tmux session: $TMUX_SESSION"
    tmux kill-session -t "$TMUX_SESSION"
fi

# Create a new detached tmux session.
tmux new-session -d -s "$TMUX_SESSION"

# Create temporary script with full variable expansions
cat > "$TMP_SCRIPT" << 'EOFSCRIPT'
#!/bin/bash

# These variables will be replaced by sed
OUTPUT_VAR="__OUTPUT_PLACEHOLDER__"
TMUX_SESSION_VAR="__TMUX_SESSION_PLACEHOLDER__"
SYNC_AFTER_GENERATION_VAR="__SYNC_AFTER_GENERATION_PLACEHOLDER__"
EXIT_TMUX_VAR="__EXIT_TMUX_PLACEHOLDER__"
MEDIA_ROOT_VAR="__MEDIA_ROOT_PLACEHOLDER__"
HDD_PATTERN_VAR="__HDD_PATTERN_PLACEHOLDER__"
AUTOSAVE_GB_VAR="__AUTOSAVE_GB_PLACEHOLDER__"
BLOCKSIZE_VAR="__BLOCKSIZE_PLACEHOLDER__"
NOHIDDEN_VAR="__NOHIDDEN_PLACEHOLDER__"
CONTENT_FILE_PER_DRIVE_VAR="__CONTENT_FILE_PER_DRIVE_PLACEHOLDER__"
RELATIVE_PATH_PER_DRIVE_VAR="__RELATIVE_PATH_PER_DRIVE_PLACEHOLDER__"
PRIMARY_CONTENT_PATH_VAR="__PRIMARY_CONTENT_PATH_PLACEHOLDER__"

# Pool definitions will be inserted here
declare -a POOL_DEFINITIONS=(__POOL_DEFINITIONS_PLACEHOLDER__)

# Exclusion patterns will be inserted here
declare -a EXCLUSION_PATTERNS=(__EXCLUSION_PATTERNS_PLACEHOLDER__)

echo "[+] Starting SnapRAID config generation inside tmux session: ${TMUX_SESSION_VAR}"
echo "[*] Media root directory: ${MEDIA_ROOT_VAR}"
echo "[*] Output file: ${OUTPUT_VAR}"

# Clear and recreate the config file.
echo "[*] Creating new config file..."
> "${OUTPUT_VAR}"

# Write properly formatted header and static sections.
cat << EOC >> "${OUTPUT_VAR}"
# SnapRAID configuration file generated dynamically on $(date)
# Generated by snapraider.sh

# Primary content file (metadata about your array)
content ${PRIMARY_CONTENT_PATH_VAR}
EOC

echo "[*] Processing pool definitions..."

# Process each pool definition
for pool_def in "${POOL_DEFINITIONS[@]}"; do
    # Parse the pool definition
    category=$(echo "$pool_def" | cut -d ':' -f1)
    prefix=$(echo "$pool_def" | cut -d ':' -f2)
    rel_path=$(echo "$pool_def" | cut -d ':' -f3)
    base_path="${MEDIA_ROOT_VAR}/${rel_path}"
    
    echo "[*] Processing category: $category (prefix: $prefix, path: $base_path)"
    
    # Add category header to config
    echo -e "\n# ${category}" >> "${OUTPUT_VAR}"
    
    # Find and sort HDD directories
    mapfile -d '' sorted_drives < <(find "${base_path}" -maxdepth 1 -type d -name "${HDD_PATTERN_VAR}" -print0 | sort -z)
    
    if [ ${#sorted_drives[@]} -eq 0 ]; then
        echo "[!] Warning: No ${HDD_PATTERN_VAR} directories found in ${base_path}"
        continue
    fi
    
    count=1
    for drive in "${sorted_drives[@]}"; do
        if [ -d "${drive}" ]; then
            if [ "${prefix}" = "parity" ]; then
                echo "[+] Adding parity drive: ${drive}"
                echo "parity ${drive}/snapraid.parity" >> "${OUTPUT_VAR}"
                echo "content ${drive}/${RELATIVE_PATH_PER_DRIVE_VAR}/snapraid.content" >> "${OUTPUT_VAR}"
            else
                echo "[+] Adding data drive: ${prefix}${count} ${drive}"
                echo "data ${prefix}${count} ${drive}" >> "${OUTPUT_VAR}"
                
                # Add content file for each data drive if CONTENT_FILE_PER_DRIVE is enabled
                if [ "${CONTENT_FILE_PER_DRIVE_VAR}" = true ]; then
                    echo "[+] Adding content file for ${prefix}${count}"
                    echo "content ${drive}/${RELATIVE_PATH_PER_DRIVE_VAR}/snapraid.content" >> "${OUTPUT_VAR}"
                fi
                
                ((count++))
            fi
        fi
    done
    
    # Add a blank line after each category
    echo "" >> "${OUTPUT_VAR}"
    
    echo "[*] Found and processed ${count-1} drives for ${category}"
done

# Add exclusions and configuration options.
echo "[*] Adding exclusion patterns and configuration options..."

echo -e "# Exclusions (files and directories)" >> "${OUTPUT_VAR}"
for pattern in "${EXCLUSION_PATTERNS[@]}"; do
    echo "exclude ${pattern}" >> "${OUTPUT_VAR}"
done

# Add configuration options
cat << EOC >> "${OUTPUT_VAR}"

# Automatically save the state when syncing after this many GB.
autosave ${AUTOSAVE_GB_VAR}

# Blocksize in KB
blocksize ${BLOCKSIZE_VAR}
EOC

# Add nohidden option if enabled
if [ "${NOHIDDEN_VAR}" = true ]; then
    echo -e "\n# Exclude hidden files" >> "${OUTPUT_VAR}"
    echo "nohidden" >> "${OUTPUT_VAR}"
fi

echo "[+] Config file generation complete."

if [ "${SYNC_AFTER_GENERATION_VAR}" = true ]; then
    echo "[*] Running snapraid sync..."
    snapraid -c "${OUTPUT_VAR}" sync
    echo "[+] SnapRAID sync completed."
fi

echo "[+] Finished generating config: ${OUTPUT_VAR}"
echo "[+] Exiting SnapRAID generation session."

# Conditionally close the tmux session based on EXIT_TMUX.
if [ "${EXIT_TMUX_VAR}" = true ]; then
    tmux kill-session -t "${TMUX_SESSION_VAR}"
else
    echo "[*] EXIT_TMUX is set to false, leaving tmux session open."
fi
EOFSCRIPT

# Format the array values for insertion
formatted_pools=$(printf "'%s' " "${POOL_DEFINITIONS[@]}")
formatted_exclusions=$(printf "'%s' " "${EXCLUSION_PATTERNS[@]}")

# Replace placeholders with actual values using sed
sed -i "s|__OUTPUT_PLACEHOLDER__|${OUTPUT}|g" "$TMP_SCRIPT"
sed -i "s|__TMUX_SESSION_PLACEHOLDER__|${TMUX_SESSION}|g" "$TMP_SCRIPT"
sed -i "s|__SYNC_AFTER_GENERATION_PLACEHOLDER__|${SYNC_AFTER_GENERATION}|g" "$TMP_SCRIPT"
sed -i "s|__EXIT_TMUX_PLACEHOLDER__|${EXIT_TMUX}|g" "$TMP_SCRIPT"
sed -i "s|__MEDIA_ROOT_PLACEHOLDER__|${MEDIA_ROOT}|g" "$TMP_SCRIPT"
sed -i "s|__HDD_PATTERN_PLACEHOLDER__|${HDD_PATTERN}|g" "$TMP_SCRIPT"
sed -i "s|__AUTOSAVE_GB_PLACEHOLDER__|${AUTOSAVE_GB}|g" "$TMP_SCRIPT"
sed -i "s|__BLOCKSIZE_PLACEHOLDER__|${BLOCKSIZE}|g" "$TMP_SCRIPT"
sed -i "s|__NOHIDDEN_PLACEHOLDER__|${NOHIDDEN}|g" "$TMP_SCRIPT"
sed -i "s|__CONTENT_FILE_PER_DRIVE_PLACEHOLDER__|${CONTENT_FILE_PER_DRIVE}|g" "$TMP_SCRIPT"
sed -i "s|__RELATIVE_PATH_PER_DRIVE_PLACEHOLDER__|${RELATIVE_PATH_PER_DRIVE}|g" "$TMP_SCRIPT"
sed -i "s|__PRIMARY_CONTENT_PATH_PLACEHOLDER__|${PRIMARY_CONTENT_PATH}|g" "$TMP_SCRIPT"
sed -i "s|__POOL_DEFINITIONS_PLACEHOLDER__|${formatted_pools}|g" "$TMP_SCRIPT"
sed -i "s|__EXCLUSION_PATTERNS_PLACEHOLDER__|${formatted_exclusions}|g" "$TMP_SCRIPT"

# Make the script executable
chmod +x "$TMP_SCRIPT"

# Execute the temporary script inside tmux
tmux send-keys -t "$TMUX_SESSION" "bash \"$TMP_SCRIPT\"; rm \"$TMP_SCRIPT\"" C-m

echo "[*] Script completed. Check the tmux session '${TMUX_SESSION}' for progress."
