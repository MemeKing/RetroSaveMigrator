#!/bin/bash

# Configuration
ROMS_PATH="./Roms"
SAVES_PATH="./Saves/CurrentProfile"
SAVE_EXTENSIONS=(".dsv" ".sav" ".srm")
DRY_RUN_MODE=false  # When true, don't actually rename files. Also includes sleeps
                    # in execution so you can see what's happening.  

# Save file extensions used in search. Add extensions here if needed.


# Initialize missing games list file.
LOG_FILE="missing_games.txt"
echo "Unmatched save files - $(date)" > "$LOG_FILE"
echo "------" >> "$LOG_FILE"

# Function to sanitize filenames while preserving numbered endings
sanitize_name() {
    local name="$1"
    suffix=$(echo "$name" | grep -oE '_([0-9]+)$' || echo "") # Extract potential number suffix (like _10)
    search_name=${name%"$suffix"} # Remove the suffix for searching
    search_name=$(echo "$search_name" | sed 's/\(\[.*$\|(\).*$//') # Remove everything after first [ or ( 
    search_name=$(echo "$search_name" | tr -d "'") # Remove single quotes to prevent parsing issues
    search_name=$(echo "$search_name" | sed 's/[ .]*$//') # Trim trailing spaces and dots
    # Return both parts separately
    echo "${search_name}${suffix}"
}

# Process each save file extension
for ext in "${SAVE_EXTENSIONS[@]}"; do
    # Find all save files with current extension
    find "$SAVES_PATH" -type f -name "*$ext" | while read -r savefile; do
        # Get base filename without extension
        save_basename=$(basename "$savefile" "$ext")
        
        # Sanitize name
        sanitized_full=$(sanitize_name "$save_basename")
        # Extract components
        suffix=$(echo "$sanitized_full" | grep -oE '_([0-9]+)$' || echo "")
        search_name=${sanitized_full%"$suffix"}
        
        # Check if exact match exists in Roms and skip (excluding .png and .pdf. Remove these filters for more speed at risk of missing an absent game)
        if find "./Roms" -type f -name "$save_basename.*" ! -name "*.png" ! -name "*.pdf" | grep -q .; then
            echo "Exact match exists for $save_basename, skipping..."
            continue
        fi
        
        # Use fzf to search for matching ROMs (excluding .png and .pdf)
        rom_match=$(find "$ROMS_PATH" -type f \( -iname "*${search_name}*" ! -name "*.png" ! -name "*.pdf" \) | fzf \
            --select-1 \
            --exit-0 \
            --preview "echo -e 'Save file:\\n$savefile\\n\\nWill be renamed to match this ROM (keeping suffix ${suffix}):' && echo {}" \
            --preview-window=up:40%)
        
        if [ -n "$rom_match" ]; then
            # Get the base name of the matched ROM (without extension)
            rom_basename=$(basename "$rom_match")
            rom_basename_noext="${rom_basename%.*}"
            
            # Rename the save file (preserving the number suffix)
            save_dir=$(dirname "$savefile")
            new_savefile="$save_dir/${rom_basename_noext}${suffix}${ext}"
            
            echo "Renaming:"
            echo "  From: $savefile"
            echo "  To:   $new_savefile"
            
            if [ "$dry_run_mode" = false ]; then
                mv "$savefile" "$new_savefile"
                echo "Renamed successfully"
            else
                echo "Dry run: Not actually renaming. Change dry_run to false to commit changes."
                sleep 3
            fi
        else
            echo "No match found for $save_basename (search term: $search_name)"
            echo "$savefile" >> "$LOG_FILE"
        fi
    done
done

echo "Processing complete."
if [ "$DRY_RUN_MODE" = true ]; then
    echo "NOTE: Running in dry run mode - no files were actually renamed"
fi
echo "Unmatched files logged to: $LOG_FILE"
