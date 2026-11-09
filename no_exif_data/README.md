# Files Without EXIF Dates

The parent directory's `rename.sh` moves images here when it cannot read a usable `DateTimeOriginal` or `ModifyDate` EXIF value. It preserves the original filename and resolves collisions by adding `_1`, `_2`, and later suffixes.

To rename these files using their filesystem modification dates, run this directory's `rename.sh` from the directory containing the files:

```bash
cd /path/to/images/no_exif_data
/path/to/bash_img_bulk_rename_tools/no_exif_data/rename.sh
```

That script processes JPG, JPEG, and PNG files in the current directory only. It uses `FileModifyDate` and moves files without a usable date into `no_data/`. Check the top-level README for requirements and cautions before running.
