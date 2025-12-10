#!/bin/bash

# Script to compare lexers between Tartrazine and Chroma
# Reports only substantial differences (not just whitespace)

TARTRAZINE_LEXERS="/home/ralsina/code/tartrazine/lexers"
CHROMA_LEXERS="/home/ralsina/code/tartrazine/chroma/lexers/embedded"

echo "# Lexer Comparison Report"
echo "# Comparing Tartrazine vs Chroma lexers"
echo "# Only showing substantial differences (not just whitespace)"
echo ""
echo "## Lexers with Differences:"
echo ""

# Get list of common lexers
comm -12 /tmp/chroma_lexers.txt /tmp/tartrazine_lexers.txt > /tmp/common_lexers.txt

substantial_diffs=0
total_checked=0

while IFS= read -r lexer; do
    tartrazine_file="$TARTRAZINE_LEXERS/$lexer"
    chroma_file="$CHROMA_LEXERS/$lexer"

    if [[ -f "$tartrazine_file" && -f "$chroma_file" ]]; then
        # Normalize both files (remove whitespace differences) and compare
        # First check if there are any differences at all
        if ! diff -q "$tartrazine_file" "$chroma_file" > /dev/null 2>&1; then
            # Check if differences are substantial (not just whitespace)
            tartrazine_normalized=$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "$tartrazine_file" | tr -d '\n\r' | tr -s ' ')
            chroma_normalized=$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "$chroma_file" | tr -d '\n\r' | tr -s ' ')

            if [[ "$tartrazine_normalized" != "$chroma_normalized" ]]; then
                echo "### $lexer"
                echo "**Differences found:**"
                diff -u "$tartrazine_file" "$chroma_file" | head -20
                echo ""
                echo "---"
                echo ""
                ((substantial_diffs++))
            fi
        fi
        ((total_checked++))
    fi
done < /tmp/common_lexers.txt

echo "## Summary:"
echo "- Total lexers compared: $total_checked"
echo "- Lexers with substantial differences: $substantial_diffs"
echo "- Lexers identical (except whitespace): $((total_checked - substantial_diffs))"
