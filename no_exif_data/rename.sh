#!/usr/bin/env bash

# ============================================================
# BULK PHOTO RENAMER (FileModifyDate)
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
#   Directory: 755
#   Files:     644
#
# SCOPE:
#   Current directory only
#
# Options:
#   --dry-run / -n    Show what would happen without changing files
#   --help / -h       Show this help
#
# Environment:
#   PREFIX=...        Filename prefix (default: IMG_)
#   EXIFTOOL=...      Path to exiftool binary
# ============================================================


# -------------------- CONFIGURATION -------------------------

EXIFTOOL="${EXIFTOOL:-$(command -v exiftool || true)}"
if [[ -z "$EXIFTOOL" && -x /usr/bin/vendor_perl/exiftool ]]; then
    EXIFTOOL="/usr/bin/vendor_perl/exiftool"
fi

PREFIX="${PREFIX:-IMG_}"
NO_DATA_DIR="no_data"

DIR_PERMISSIONS="755"
FILE_PERMISSIONS="644"

DRY_RUN=0


# -------------------- HELP ----------------------------------

show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Bulk rename JPG/JPEG/PNG files using filesystem modification time (FileModifyDate).

Options:
  -n, --dry-run    Show what would be done without changing any files
  -h, --help       Show this help message

Environment variables:
  PREFIX           Filename prefix (default: IMG_)
  EXIFTOOL         Path to exiftool binary

Examples:
  ./rename.sh
  ./rename.sh --dry-run
  PREFIX=PHOTO_ ./rename.sh
EOF
}


# -------------------- ARGUMENT PARSING ----------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done


# -------------------- CHECK DEPENDENCIES --------------------

if ! command -v "$EXIFTOOL" >/dev/null 2>&1; then
    echo "ERROR: ExifTool not found:"
    echo "  $EXIFTOOL"
    echo
    echo "Install with:"
    echo "  sudo pacman -S perl-image-exiftool          # Arch"
    echo "  sudo apt install libimage-exiftool-perl     # Debian/Ubuntu"
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

    if [[ $DRY_RUN -eq 1 ]]; then
        return 0
    fi

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

if [[ $DRY_RUN -eq 1 ]]; then
    echo "=== DRY-RUN MODE (no files will be changed) ==="
    echo
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

        if [[ $DRY_RUN -eq 1 ]]; then
            echo "WOULD MOVE: $filename -> $destination"
            ((moved++))
        else
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
        fi

        continue

    fi


    # --------------------------------------------------------
    # BUILD NEW FILENAME
    # --------------------------------------------------------

    new_name="${PREFIX}${photo_date}.${extension}"


    # --------------------------------------------------------
    # SKIP IF ALREADY CORRECT (exact or with collision suffix)
    # --------------------------------------------------------

    if [[ "$filename" =~ ^${PREFIX}[0-9]{8}_[0-9]{6}(_[0-9]+)?\.[jJpPnNgG]+$ ]]; then

        echo "SKIP (already named): $filename"
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

    if [[ $DRY_RUN -eq 1 ]]; then
        echo "WOULD RENAME: $filename -> $destination"
        ((renamed++))
    else
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
    fi

done


# -------------------- FINAL SUMMARY -------------------------

echo
echo "============================================================"
if [[ $DRY_RUN -eq 1 ]]; then
    echo "DRY-RUN COMPLETED (no files were changed)"
else
    echo "PROCESS COMPLETED"
fi
echo "============================================================"
echo "Renamed       : $renamed"
echo "Moved         : $moved"
echo "Skipped       : $skipped"
echo "Errors        : $errors"
echo "============================================================"
echo "Date source         : System FileModifyDate"
echo "Prefix              : $PREFIX"
echo "Folder permissions  : $DIR_PERMISSIONS"
echo "File permissions    : $FILE_PERMISSIONS"
echo "============================================================"
