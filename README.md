# Bulk Image Renaming Tools

Two Bash scripts that rename image files in the current directory using different date sources:

- **`rename.sh`** uses EXIF `DateTimeOriginal`, then falls back to EXIF `ModifyDate`.  
  Processes `.jpg` and `.jpeg` files.  
  Files without a usable EXIF date are moved to `no_exif_data/`.

- **`no_exif_data/rename.sh`** uses the filesystem `FileModifyDate` only.  
  Processes `.jpg`, `.jpeg`, and `.png` files.  
  Files without a usable date are moved to its `no_data/` subdirectory.

Both scripts produce names in the form `IMG_YYYYMMDD_HHMMSS.ext`.  
The EXIF-based script appends three millisecond digits when the matching EXIF subsecond tag is available.  
If a target name already exists, the script adds `_1`, `_2`, and so on before the extension.  
Existing files that already match the naming pattern are skipped.

## Requirements

- Bash
- ExifTool (`exiftool`), available on `PATH`

On Arch Linux:

```bash
sudo pacman -S perl-image-exiftool
```

On Debian/Ubuntu:

```bash
sudo apt install libimage-exiftool-perl
```

To use a non-standard ExifTool executable:

```bash
EXIFTOOL=/custom/path/exiftool ./rename.sh
```

## Usage

Run the desired script **from the directory containing the images**.  
Each script only scans the current directory (no recursion).

### Basic usage

```bash
cd /path/to/images
/path/to/bash_img_bulk_rename_tools/rename.sh
```

For filesystem modification dates instead:

```bash
cd /path/to/images
/path/to/bash_img_bulk_rename_tools/no_exif_data/rename.sh
```

### Dry-run mode (recommended first)

See what the script *would* do without changing any files:

```bash
./rename.sh --dry-run
# or
./rename.sh -n
```

### Custom filename prefix

```bash
PREFIX=PHOTO_ ./rename.sh
PREFIX=PXL_ ./rename.sh --dry-run
```

### Help

```bash
./rename.sh --help
```

## Options

| Flag            | Description                                      |
|-----------------|--------------------------------------------------|
| `-n`, `--dry-run` | Preview actions without renaming or moving files |
| `-h`, `--help`    | Show usage information                           |

## Environment Variables

| Variable   | Default | Description                          |
|------------|---------|--------------------------------------|
| `PREFIX`   | `IMG_`  | Prefix used in the new filenames     |
| `EXIFTOOL` | auto    | Path to the `exiftool` binary        |

## Output Folders

- `no_exif_data/` is created beside the images by the EXIF-based script for images without usable capture-date metadata.
- `no_data/` is created inside the current directory by the filesystem-date script for images without a usable modification date.

## Important Notes

- Always review the selected date source before running.
- Filesystem modification time can change when files are copied.
- EXIF metadata can be absent or inaccurate.
- **Back up important files first.**
- The scripts rename or move images in place and set output files to mode `644` and directories to mode `755`.

## License

This project is released under the 0BSD license. See [LICENSE](LICENSE) for the full text.
