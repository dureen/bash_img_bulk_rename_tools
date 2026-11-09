# Bulk Image Renaming Tools

Two Bash scripts rename image files in the current directory using different date sources:

- `rename.sh` uses EXIF `DateTimeOriginal`, then falls back to EXIF `ModifyDate`. It processes `.jpg` and `.jpeg` files. Files without a usable EXIF date are moved to `no_exif_data/`.
- `no_exif_data/rename.sh` uses the filesystem `FileModifyDate` only. It processes `.jpg`, `.jpeg`, and `.png` files. Files without a usable date are moved to its `no_data/` subdirectory.

Both scripts produce names in the form `IMG_YYYYMMDD_HHMMSS.ext`. The EXIF-based script appends three millisecond digits when the matching EXIF subsecond tag is available. If a target name already exists, the script adds `_1`, `_2`, and so on before the extension. Existing files that already match the EXIF script's naming pattern are skipped.

## Requirements

- Bash
- ExifTool (`exiftool`), available on `PATH`

On Arch Linux, install ExifTool with `sudo pacman -S perl-image-exiftool`. On other distributions, install the package named `exiftool` or `libimage-exiftool-perl` using the system package manager.

To use a non-standard ExifTool executable, set `EXIFTOOL` to its path when running a script, for example:

```bash
EXIFTOOL=/custom/path/exiftool ./rename.sh
```

## Usage

Run the desired script from the directory containing the images. Each script only scans that directory; it does not recurse into subdirectories.

```bash
cd /path/to/images
/path/to/bash_img_bulk_rename_tools/rename.sh
```

For filesystem modification dates instead, run the second script:

```bash
cd /path/to/images
/path/to/bash_img_bulk_rename_tools/no_exif_data/rename.sh
```

Review the selected date source before running: filesystem modification time may change when files are copied, and EXIF metadata can be absent or inaccurate. Back up important files first. The scripts rename or move images in place and set output files to mode `644` and output directories to mode `755`.

## Output Folders

- `no_exif_data/` is created beside the images by the EXIF-based script for images without usable capture-date metadata.
- `no_data/` is created inside the current directory by the filesystem-date script for images without a usable modification date. When running that script from this repository's `no_exif_data/` folder, this is `no_exif_data/no_data/`.
