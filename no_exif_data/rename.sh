
#!/usr/bin/env bash

# ============================================================
# BULK PHOTO RENAMER
#
# DATE SOURCE:
#   [System] FileModifyDate ONLY
#
# SUPPORTED FILES:
#   JPG, JPEG, PNG
#
# FILENAME:
#   IMG_YYYYMMDD_HHMMSS.ext
#
# DUPLICATE HANDLING:
#   filename.ext
#   filename_1.ext
#   filename_2.ext
#
# FILES WITHOUT USABLE DATES:
#   Move to no_data/
#
# PERMISSIONS:
#   Directory: 777
#   Files:     644
#
# SCOPE:
#   Current directory only
# ============================================================


# -------------------- CONFIGURATION -------------------------

EXIFTOOL="${EXIFTOOL:-$(command -v exiftool || true)}"
if [[ -z "$EXIFTOOL" && -x /usr/bin/vendor_perl/exiftool ]]; then
    EXIFTOOL="/usr/bin/vendor_perl/exiftool"
fi

PREFIX="IMG_"
NO_DATA_DIR="no_data"

DIR_PERMISSIONS="755"
FILE_PERMISSIONS="644"


# -------------------- CHECK DEPENDENCIES --------------------

if ! command -v "$EXIFTOOL" >/dev/null 2>&1; then
    echo "ERROR: ExifTool not found:"
    echo "$EXIFTOOL"
    echo
    echo "Install with:"
    echo "sudo pacman -S perl-image-exiftool"
    exit 1
fi


# -------------------- DATE FUNCTION -------------------------

find_photo_date() {
    local file="$1"
    local datetime=""

    # Use ONLY [System] FileModifyDate
    datetime=$(
        "$EXIFTOOL" -s3 -d '%Y%m%d_%H%M%S' \
            -FileModifyDate "$file" 2>/dev/null
    )

    if [[ "$datetime" =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
        printf '%s\n' "$datetime"
        return 0
    fi

    return 1
}


# -------------------- UNIQUE FILENAME FUNCTION -------------

get_unique_filename() {
    local directory="$1"
    local filename="$2"

    local name="${filename%.*}"
    local extension="${filename##*.}"

    local candidate="$directory/$filename"
    local counter=1

    while [[ -e "$candidate" ]]; do
        candidate="$directory/${name}_${counter}.${extension}"
        ((counter++))
    done

    printf '%s\n' "$candidate"
}


# -------------------- DIRECTORY PREPARATION ----------------

prepare_no_data_directory() {

    mkdir -p "$NO_DATA_DIR" || return 1

    chmod "$DIR_PERMISSIONS" "$NO_DATA_DIR" || return 1

    # Set permissions on existing files
    find "$NO_DATA_DIR" -maxdepth 1 -type f \
        -exec chmod "$FILE_PERMISSIONS" {} \; || return 1
}


# -------------------- MAIN PROCESS --------------------------

shopt -s nullglob nocaseglob

if ! prepare_no_data_directory; then
    echo "ERROR: Cannot prepare $NO_DATA_DIR"
    exit 1
fi

renamed=0
moved=0
skipped=0
errors=0


for file in *.jpg *.jpeg *.png; do

    [[ -f "$file" ]] || continue

    filename=$(basename "$file")
    extension="${filename##*.}"


    # --------------------------------------------------------
    # GET FILEMODIFYDATE
    # --------------------------------------------------------

    photo_date=$(find_photo_date "$file")


    # --------------------------------------------------------
    # NO USABLE FILEMODIFYDATE
    # --------------------------------------------------------

    if [[ -z "$photo_date" ]]; then

        destination=$(get_unique_filename "$NO_DATA_DIR" "$filename")

        if mv -n -- "$file" "$destination" &&
           [[ ! -e "$file" ]]; then

            echo "MOVED: $filename -> $destination"
            ((moved++))

            if ! chmod "$FILE_PERMISSIONS" "$destination"; then
                echo "ERROR setting permissions on: $destination"
                ((errors++))
            fi

        else

            echo "ERROR moving: $filename"
            ((errors++))

        fi

        continue

    fi


    # --------------------------------------------------------
    # BUILD NEW FILENAME
    # --------------------------------------------------------

    new_name="${PREFIX}${photo_date}.${extension}"


    # --------------------------------------------------------
    # SKIP ONLY IF EXACTLY CORRECT
    # --------------------------------------------------------

    if [[ "$filename" == "$new_name" ]]; then

        echo "SKIP (already correct): $filename"
        ((skipped++))
        continue

    fi


    # --------------------------------------------------------
    # GET UNIQUE DESTINATION
    # --------------------------------------------------------

    destination=$(get_unique_filename "." "$new_name")
    destination="${destination#./}"


    # --------------------------------------------------------
    # RENAME PHOTO
    # --------------------------------------------------------

    if mv -n -- "$file" "$destination" &&
       [[ ! -e "$file" ]]; then

        echo "RENAMED: $filename -> $destination"
        ((renamed++))

        if ! chmod "$FILE_PERMISSIONS" "$destination"; then
            echo "ERROR setting permissions on: $destination"
            ((errors++))
        fi

    else

        echo "ERROR renaming: $filename"
        ((errors++))

    fi

done


# -------------------- FINAL SUMMARY -------------------------

echo
echo "============================================================"
echo "PROCESS COMPLETED"
echo "============================================================"
echo "Renamed       : $renamed"
echo "Moved         : $moved"
echo "Skipped       : $skipped"
echo "Errors        : $errors"
echo "============================================================"
echo "Date source         : System FileModifyDate"
echo "Folder permissions : $DIR_PERMISSIONS"
echo "File permissions   : $FILE_PERMISSIONS"
echo "============================================================"
