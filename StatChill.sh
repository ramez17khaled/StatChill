#!/bin/bash
set -e  # Exit script on any error

# Start the Python GUI script
python GUI.py

# Read the generated config file
config_file="config.txt"

if [ ! -f "$config_file" ]; then
    echo "Config file not found. Exiting."
    exit 1
fi

# Read each line in config.txt to set variables
while IFS='=' read -r key value; do
    key=$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr -d ' ')
    eval "${key}='${value}'"
done < "$config_file"

# Call the appropriate script based on the method
if [ "$METHOD" = "PLS-Da" ]; then
    python PLS-Da.py "$META_FILE_PATH" "$FILE_PATH" "$SHEET" "$OUTPUT_PATH" "$COLUMN" "$CONDITIONS"
elif [ "$METHOD" = "Volcano" ]; then
    Rscript Volcano.R "$META_FILE_PATH" "$FILE_PATH" "$SHEET" "$OUTPUT_PATH" "$COLUMN" "$CONDITIONS"
elif [ "$METHOD" = "ANOVA" ]; then
    python testing.py "$config_file"
elif [ "$METHOD" = "PCA" ]; then
    Rscript PCA.R "$META_FILE_PATH" "$FILE_PATH" "$SHEET" "$OUTPUT_PATH" "$COLUMN" "$CONDITIONS"
elif [ "$METHOD" = "batchCorrect" ]; then
    Rscript batchCorrecting.R "$META_FILE_PATH" "$FILE_PATH" "$SHEET" "$OUTPUT_PATH" "$COLUMN" "$CONDITIONS" "$LABEL_COLUMN"
else
    echo "Unsupported method: $METHOD"
    exit 1
fi
