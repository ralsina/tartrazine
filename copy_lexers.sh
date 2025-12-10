#!/bin/bash

# Copy lexers with substantial differences from Chroma to Tartrazine

comm -12 /tmp/chroma_lexers.txt /tmp/tartrazine_lexers.txt > /tmp/common_lexers.txt

copied=0

while IFS= read -r lexer; do
    tartrazine_file="/home/ralsina/code/tartrazine/lexers/$lexer"
    chroma_file="/home/ralsina/code/tartrazine/chroma/lexers/embedded/$lexer"

    if [[ -f "$tartrazine_file" && -f "$chroma_file" ]]; then
        # Normalize both files to check for substantial differences
        tartrazine_normalized=$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "$tartrazine_file" | tr -d '\n\r' | tr -s ' ')
        chroma_normalized=$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "$chroma_file" | tr -d '\n\r' | tr -s ' ')

        if [[ "$tartrazine_normalized" != "$chroma_normalized" ]]; then
            echo "Copying $lexer from Chroma..."
            cp "$chroma_file" "$tartrazine_file"
            ((copied++))
        fi
    fi
done < /tmp/common_lexers.txt

echo "Copied $copied lexers with updates from Chroma."
