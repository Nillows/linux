#!/bin/bash

# ======================= USER CONFIG SECTION =======================
# Change these variables to match your setup

# Basic configuration
FILENAME="output.txt"           # Change to 'snapraid.conf' for production
DEST_DIR="$(pwd)"               # Change to '/etc' for production
TMP_SCRIPT="/tmp/snapraid_gen.sh"  # Location for temporary script
TMUX_SESSION="snapraider"       # Name of the tmux session

# Media root directory - base path for all media
MEDIA_ROOT="/var/lib/emby/media"  # Change this to your media root directory

# Content file settings
CONTENT_FILE_PER_DRIVE=true     # If true, creates a content file on each data drive for redundancy
RELATIVE_PATH_PER_DRIVE="snapraid"     # Relative path within each drive for content files (e.g., "." for root, "snapraid" for subdirectory)
PRIMARY_CONTENT_PATH="/var/snapraid.content"  # Path for the primary content file

# Define your pool categories and paths
# Format: "Category Name:prefix:/path/relative/to/media/root"
# Each line defines one category, with a friendly name, the prefix for data disks, and subdirectory

# Step 1) Make new category directory in MEDIA_ROOT
# Step 2) Add at least one subdirectory following HDD_PATTERN naming scheme below.

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
CHECK_DATE=true                # Check modification dates before generating new config
EXIT_TMUX=false                # If true, tmux session closes after completion
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
# Setting an option to 'true' will add it to the snapraid.conf file; 'false' will exclude it

# Hidden Files Options
NOHIDDEN=true                   # When true, adds 'nohidden' to the config, instructing SnapRAID to skip hidden files/directories
                                # This typically excludes .* files in Linux/Unix and improves performance
                                # When false, hidden files will be included in parity calculations

# SMART Monitoring Configuration
ENABLE_SMART_MONITORING=false      # When true, adds SMART monitoring capability via 'smart /path/to/smartctl' command in config
                                   # This allows SnapRAID to check disk health and report failing drives
                                   # Requires smartmontools to be installed on your system
SMART_COMMAND="/usr/sbin/smartctl" # Path to the smartctl executable (only used if SMART_MONITORING=true)
                                   # This must point to a valid smartctl installation for SMART monitoring to work

# Disk Scrubbing Options
ENABLE_DISK_SCRUB=false         # When true, adds the 'scrub N' directive to regularly validate your data
                                # Scrubbing reads the entire array and validates checksums, helping detect silent corruption
                                # Regular scrubbing is highly recommended for data integrity
SCRUB_PERCENTAGE=8              # Percentage of the array to scrub (1-100) when running 'snapraid scrub'
                                # Lower values are faster but less thorough; higher values provide more validation
                                # Only used if ENABLE_DISK_SCRUB=true

# Access Mode Options
ENABLE_READ_ONLY=false          # When true, adds 'readonly' option to prevent changes to the array via SnapRAID
                                # This is a safety feature that prevents accidental modifications
                                # Useful for arrays that should be considered 'archived' or read-only

# Performance Tuning Options
ENABLE_CPU_AFFINITY=false       # When true, adds 'cpu N,N,N' option to bind SnapRAID to specific CPU cores
                                # This can improve performance on multi-core systems by controlling CPU allocation
                                # Particularly useful on busy systems or when running CPU-intensive tasks
CPU_CORES="1,2"                 # Comma-separated list of CPU cores to use (only used if CPU_AFFINITY=true)
                                # Format: "0,1,2" or "0-3" to specify which cores SnapRAID should use

# Data Integrity Options
ENABLE_HASH_ALGORITHM=false     # When true, adds 'hash ALGORITHM' to use a specific hash algorithm for checksums
                                # Different algorithms offer different trade-offs between speed and security
                                # For most home users, the default is sufficient
HASH_ALGORITHM="murmur3"        # Hash algorithm to use: sha1, sha256, sha3, blake2, xxhash, murmur3
                                # murmur3 is fastest, sha256/sha3 are most secure (only if HASH_ALGORITHM=true)

# Memory and I/O Management
ENABLE_IO_CACHE_SIZE=false      # When true, adds 'io-cache SIZE' to configure memory used for I/O operations
                                # Larger cache may improve performance but uses more system memory
                                # Default is typically suitable for most systems
IO_CACHE_SIZE=32                # Size in MB for I/O cache (only used if IO_CACHE_SIZE=true)
                                # Recommended range: 16-256 depending on available system RAM

# Performance Limiting
ENABLE_SPEED_LIMIT=false        # When true, adds 'speed-limit N' to restrict SnapRAID's disk bandwidth usage
                                # Useful to prevent SnapRAID from consuming all I/O bandwidth
                                # Helpful when running SnapRAID on an active system
SPEED_LIMIT=100                 # Maximum speed in MB/s (only used if SPEED_LIMIT=true)
                                # Lower values reduce impact on system performance but increase operation time

# Windows-Specific Features
ENABLE_WINDOWS_VSS=false        # When true, adds 'vss' option to use Windows Volume Shadow Copy Service
                                # This allows SnapRAID to safely work with files that are in use
                                # Windows-only feature - has no effect on Linux/Unix systems

# Storage Allocation
ENABLE_PREALLOC=false           # When true, adds 'prealloc' to pre-allocate space for parity files
                                # This can prevent fragmentation and improve performance
                                # Especially useful for systems with limited free space
PREALLOC_SIZE=0                 # Size in GB to pre-allocate (0 for full size - recommended)
                                # Only used if PREALLOC=true

# Specialized Options
ENABLE_FORCE_ZERO=false         # When true, adds 'force-zero' to zero-fill unused blocks in parity
                                # Increases security but reduces performance
                                # Most home users don't need this option

# Logging and Debugging
ENABLE_EXTRA_LOGGING=false       # When true, adds 'log /path/to/logfile' for detailed operation logging
                                 # Helps with troubleshooting but creates additional files
                                 # Mainly useful for debugging issues
LOG_PATH="/var/log/snapraid.log" # Path for log file if extra logging is enabled
                                 # Only used if EXTRA_LOGGING=true

# Pool Feature Configuration
ENABLE_POOL_NAMES=false         # When true, adds 'pool /path' to enable the SnapRAID pool feature
                                # This creates convenient links to your content in a unified directory
                                # Makes browsing the array easier, similar to mergerfs/unionfs
POOL_STORAGE_PATH="/mnt/pool"   # Path where pool links will be created (only if POOL_NAMES=true)
                                # This should be an empty directory dedicated to pool links
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
ENABLE_SMART_MONITORING_VAR="__ENABLE_SMART_MONITORING_PLACEHOLDER__"
SMART_COMMAND_VAR="__SMART_COMMAND_PLACEHOLDER__"
ENABLE_DISK_SCRUB_VAR="__ENABLE_DISK_SCRUB_PLACEHOLDER__"
SCRUB_PERCENTAGE_VAR="__SCRUB_PERCENTAGE_PLACEHOLDER__"
ENABLE_READ_ONLY_VAR="__ENABLE_READ_ONLY_PLACEHOLDER__"
ENABLE_CPU_AFFINITY_VAR="__ENABLE_CPU_AFFINITY_PLACEHOLDER__"
CPU_CORES_VAR="__CPU_CORES_PLACEHOLDER__"
ENABLE_HASH_ALGORITHM_VAR="__ENABLE_HASH_ALGORITHM_PLACEHOLDER__"
HASH_ALGORITHM_VAR="__HASH_ALGORITHM_PLACEHOLDER__"
ENABLE_IO_CACHE_SIZE_VAR="__ENABLE_IO_CACHE_SIZE_PLACEHOLDER__"
IO_CACHE_SIZE_VAR="__IO_CACHE_SIZE_PLACEHOLDER__"
ENABLE_SPEED_LIMIT_VAR="__ENABLE_SPEED_LIMIT_PLACEHOLDER__"
SPEED_LIMIT_VAR="__SPEED_LIMIT_PLACEHOLDER__"
ENABLE_WINDOWS_VSS_VAR="__ENABLE_WINDOWS_VSS_PLACEHOLDER__"
ENABLE_PREALLOC_VAR="__ENABLE_PREALLOC_PLACEHOLDER__"
PREALLOC_SIZE_VAR="__PREALLOC_SIZE_PLACEHOLDER__"
ENABLE_FORCE_ZERO_VAR="__ENABLE_FORCE_ZERO_PLACEHOLDER__"
ENABLE_EXTRA_LOGGING_VAR="__ENABLE_EXTRA_LOGGING_PLACEHOLDER__"
LOG_PATH_VAR="__LOG_PATH_PLACEHOLDER__"
ENABLE_POOL_NAMES_VAR="__ENABLE_POOL_NAMES_PLACEHOLDER__"
POOL_STORAGE_PATH_VAR="__POOL_STORAGE_PATH_PLACEHOLDER__"

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
            # Function to join paths without double slashes or unnecessary .
            join_path() {
                local base="$1"
                local rel="$2"
                local file="$3"
                
                if [ "$rel" = "." ] || [ -z "$rel" ]; then
                    echo "${base}/${file}"
                else
                    echo "${base}/${rel}/${file}"
                fi
            }
            
            if [ "${prefix}" = "parity" ]; then
                echo "[+] Adding parity drive: ${drive}"
                echo "parity ${drive}/snapraid.parity" >> "${OUTPUT_VAR}"
                content_path=$(join_path "${drive}" "${RELATIVE_PATH_PER_DRIVE_VAR}" "snapraid.content")
                echo "content ${content_path}" >> "${OUTPUT_VAR}"
            else
                echo "[+] Adding data drive: ${prefix}${count} ${drive}"
                echo "data ${prefix}${count} ${drive}" >> "${OUTPUT_VAR}"
                
                # Add content file for each data drive if CONTENT_FILE_PER_DRIVE is enabled
                if [ "${CONTENT_FILE_PER_DRIVE_VAR}" = true ]; then
                    echo "[+] Adding content file for ${prefix}${count}"
                    content_path=$(join_path "${drive}" "${RELATIVE_PATH_PER_DRIVE_VAR}" "snapraid.content")
                    echo "content ${content_path}" >> "${OUTPUT_VAR}"
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
sed -i "s|__ENABLE_SMART_MONITORING_PLACEHOLDER__|${ENABLE_SMART_MONITORING}|g" "$TMP_SCRIPT"
sed -i "s|__SMART_COMMAND_PLACEHOLDER__|${SMART_COMMAND}|g" "$TMP_SCRIPT"
sed -i "s|__ENABLE_DISK_SCRUB_PLACEHOLDER__|${ENABLE_DISK_SCRUB}|g" "$TMP_SCRIPT"
sed -i "s|__SCRUB_PERCENTAGE_PLACEHOLDER__|${SCRUB_PERCENTAGE}|g" "$TMP_SCRIPT"
sed -i "s|__ENABLE_READ_ONLY_PLACEHOLDER__|${ENABLE_READ_ONLY}|g" "$TMP_SCRIPT"
sed -i "s|__ENABLE_CPU_AFFINITY_PLACEHOLDER__|${ENABLE_CPU_AFFINITY}|g" "$TMP_SCRIPT"
sed -i "s|__CPU_CORES_PLACEHOLDER__|${CPU_CORES}|g" "$TMP_SCRIPT"
sed -i "s|__ENABLE_HASH_ALGORITHM_PLACEHOLDER__|${ENABLE_HASH_ALGORITHM}|g" "$TMP_SCRIPT"
sed -i "s|__HASH_ALGORITHM_PLACEHOLDER__|${HASH_ALGORITHM}|g" "$TMP_SCRIPT"
sed -i "s|__ENABLE_IO_CACHE_SIZE_PLACEHOLDER__|${ENABLE_IO_CACHE_SIZE}|g" "$TMP_SCRIPT"
sed -i "s|__IO_CACHE_SIZE_PLACEHOLDER__|${IO_CACHE_SIZE}|g" "$TMP_SCRIPT"
sed -i "s|__ENABLE_SPEED_LIMIT_PLACEHOLDER__|${ENABLE_SPEED_LIMIT}|g" "$TMP_SCRIPT"
sed -i "s|__SPEED_LIMIT_PLACEHOLDER__|${SPEED_LIMIT}|g" "$TMP_SCRIPT"
sed -i "s|__ENABLE_WINDOWS_VSS_PLACEHOLDER__|${ENABLE_WINDOWS_VSS}|g" "$TMP_SCRIPT"
sed -i "s|__ENABLE_PREALLOC_PLACEHOLDER__|${ENABLE_PREALLOC}|g" "$TMP_SCRIPT"
sed -i "s|__PREALLOC_SIZE_PLACEHOLDER__|${PREALLOC_SIZE}|g" "$TMP_SCRIPT"
sed -i "s|__ENABLE_FORCE_ZERO_PLACEHOLDER__|${ENABLE_FORCE_ZERO}|g" "$TMP_SCRIPT"
sed -i "s|__ENABLE_EXTRA_LOGGING_PLACEHOLDER__|${ENABLE_EXTRA_LOGGING}|g" "$TMP_SCRIPT"
sed -i "s|__LOG_PATH_PLACEHOLDER__|${LOG_PATH}|g" "$TMP_SCRIPT"
sed -i "s|__ENABLE_POOL_NAMES_PLACEHOLDER__|${ENABLE_POOL_NAMES}|g" "$TMP_SCRIPT"
sed -i "s|__POOL_STORAGE_PATH_PLACEHOLDER__|${POOL_STORAGE_PATH}|g" "$TMP_SCRIPT"
sed -i "s|__POOL_DEFINITIONS_PLACEHOLDER__|${formatted_pools}|g" "$TMP_SCRIPT"
sed -i "s|__EXCLUSION_PATTERNS_PLACEHOLDER__|${formatted_exclusions}|g" "$TMP_SCRIPT"

# Make the script executable
chmod +x "$TMP_SCRIPT"

# Execute the temporary script inside tmux
tmux send-keys -t "$TMUX_SESSION" "bash \"$TMP_SCRIPT\"; rm \"$TMP_SCRIPT\"" C-m

echo "[*] Script completed. Check the tmux session '${TMUX_SESSION}' for progress."
