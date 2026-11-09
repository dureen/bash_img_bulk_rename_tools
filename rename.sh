
#!/usr/bin/env bash

# ============================================================
# BULK PHOTO RENAMER
#
# EXIF Date Priority:
#   1. DateTimeOriginal
#   2. ModifyDate
#
# Filename:
#   IMG_YYYYMMDD_HHMMSSmmm.jpg  (milliseconds available)
#   IMG_YYYYMMDD_HHMMSS.jpg     (otherwise)
#
# Duplicate handling:
#   filename.jpg
#   filename_1.jpg
#   filename_2.jpg
#   filename_3.jpg
#
# Photos without usable EXIF dates:
#   Moved to no_exif_data/
# ============================================================


# -------------------- CONFIGURATION -------------------------

EXIFTOOL="${EXIFTOOL:-$(command -v exiftool || true)}"
if [[ -z "$EXIFTOOL" && -x /usr/bin/vendor_perl/exiftool ]]; then
    EXIFTOOL="/usr/bin/vendor_perl/exiftool"
fi

PREFIX="IMG_"
NO_EXIF_DIR="no_exif_data"

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


# -------------------- EXIF FUNCTIONS ------------------------

get_exif_value() {
    local file="$1"
    local tag="$2"

    "$EXIFTOOL" -s3 "-$tag" "$file" 2>/dev/null
}


find_photo_date() {
    local file="$1"
    local datetime=""
    local subsecond=""
    local tag=""
    local subsec_tag=""

    # Priority 1: DateTimeOriginal
    # Priority 2: ModifyDate

    for tag in DateTimeOriginal ModifyDate; do

        datetime=$(get_exif_value "$file" "$tag")

        # Validate EXIF date format
        if [[ ! "$datetime" =~ ^[0-9]{4}:[0-9]{2}:[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
            continue
        fi

        # Get matching subsecond tag
        if [[ "$tag" == "DateTimeOriginal" ]]; then
            subsec_tag="SubSecTimeOriginal"
        else
            subsec_tag="SubSecTime"
        fi

        subsecond=$(get_exif_value "$file" "$subsec_tag")

        # Normalize milliseconds to exactly 3 digits
        if [[ "$subsecond" =~ ^[0-9]+$ ]]; then
            subsecond="${subsecond}000"
            subsecond="${subsecond:0:3}"
        else
            subsecond=""
        fi

        # Convert EXIF date into filename format
        datetime="${datetime//:/}"
        datetime="${datetime/ /_}"

        printf '%s%s\n' "$datetime" "$subsecond"
        return 0

    done

    return 1
}


# -------------------- FILENAME FUNCTIONS --------------------

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

prepare_no_exif_directory() {

    mkdir -p "$NO_EXIF_DIR" || return 1

    chmod "$DIR_PERMISSIONS" "$NO_EXIF_DIR" || return 1

    # Apply file permissions to existing files
    find "$NO_EXIF_DIR" -maxdepth 1 -type f \
        -exec chmod "$FILE_PERMISSIONS" {} \; || return 1
}


# -------------------- MAIN PROCESS --------------------------

shopt -s nullglob nocaseglob

if ! prepare_no_exif_directory; then
    echo "ERROR: Cannot prepare $NO_EXIF_DIR"
    exit 1
fi

renamed=0
moved=0
skipped=0
errors=0


for file in *.jpg *.jpeg; do

    [[ -f "$file" ]] || continue

    filename=$(basename "$file")
    extension="${filename##*.}"

    # Skip files already following the naming format
    if [[ "$filename" =~ ^${PREFIX}[0-9]{8}_[0-9]{6}([0-9]{3})?(_[0-9]+)?\.[jJ][pP][eE]?[gG]$ ]]; then

        echo "SKIP (already named): $filename"
        ((skipped++))
        continue

    fi


    # Find EXIF date and optional milliseconds
    photo_date=$(find_photo_date "$file")


    # --------------------------------------------------------
    # NO USABLE EXIF DATE
    # --------------------------------------------------------

    if [[ -z "$photo_date" ]]; then

        destination=$(get_unique_filename "$NO_EXIF_DIR" "$filename")

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
echo "Folder permissions : $DIR_PERMISSIONS"
echo "File permissions   : $FILE_PERMISSIONS"
echo "============================================================"
