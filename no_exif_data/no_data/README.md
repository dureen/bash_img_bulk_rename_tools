# Files Without Usable Modification Dates

The `no_exif_data/rename.sh` script places images here when ExifTool cannot provide a usable filesystem `FileModifyDate`. Files are moved with their original names; a numeric suffix is added if a name already exists.

This folder is an output location, not a script input. To retry these images, move or copy them to a working directory and run the appropriate renaming script there.
