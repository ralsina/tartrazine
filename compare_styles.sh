#!/bin/bash

# Script to compare styles/themes between Tartrazine and Chroma
# Reports only substantial differences (not just whitespace)

TARTRAZINE_STYLES="/home/ralsina/code/tartrazine/styles"
CHROMA_STYLES="/home/ralsina/code/tartrazine/chroma/styles"

echo "# Theme Comparison Report"
echo "# Comparing Tartrazine vs Chroma themes"
echo "# Only showing substantial differences (not just whitespace)"
echo ""

# Get list of common themes
comm -12 /tmp/chroma_styles.txt /tmp/tartrazine_styles.txt > /tmp/common_styles.txt

substantial_diffs=0
total_checked=0

while IFS= read -r theme; do
    tartrazine_file="$TARTRAZINE_STYLES/$theme"
    chroma_file="$CHROMA_STYLES/$theme"

    if [[ -f "$tartrazine_file" && -f "$chroma_file" ]]; then
        # Check if there are any differences at all
        if ! diff -q "$tartrazine_file" "$chroma_file" > /dev/null 2>&1; then
            # Check if differences are substantial (not just whitespace)
            tartrazine_normalized=$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "$tartrazine_file" | tr -d '\n\r' | tr -s ' ')
            chroma_normalized=$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "$chroma_file" | tr -d '\n\r' | tr -s ' ')

            if [[ "$tartrazine_normalized" != "$chroma_normalized" ]]; then
                echo "### $theme"
                echo "**Differences found:**"
                diff -u "$tartrazine_file" "$chroma_file" | head -15
                echo ""
                echo "---"
                echo ""
                ((substantial_diffs++))
            fi
        fi
        ((total_checked++))
    fi
done < /tmp/common_styles.txt

echo "## Summary:"
echo "- Total themes compared: $total_checked"
echo "- Themes with substantial differences: $substantial_diffs"
echo "- Themes identical (except whitespace): $((total_checked - substantial_diffs))"
