#!/bin/bash

# Copy new themes and updated themes from Chroma to Tartrazine

TARTRAZINE_STYLES="/home/ralsina/code/tartrazine/styles"
CHROMA_STYLES="/home/ralsina/code/tartrazine/chroma/styles"

echo "=== Copying New Themes ==="
# Copy new themes
new_themes=("ashen.xml" "base16-snazzy.xml" "rpgle.xml")
for theme in "${new_themes[@]}"; do
    if [[ -f "$CHROMA_STYLES/$theme" ]]; then
        echo "Copying new theme: $theme"
        cp "$CHROMA_STYLES/$theme" "$TARTRAZINE_STYLES/"
    fi
done

echo ""
echo "=== Copying Updated Themes ==="
# Copy themes with substantial differences
updated_themes=(
    "catppuccin-frappe.xml"
    "catppuccin-latte.xml"
    "catppuccin-macchiato.xml"
    "catppuccin-mocha.xml"
    "github.xml"
    "rrt.xml"
    "tango.xml"
)

for theme in "${updated_themes[@]}"; do
    if [[ -f "$CHROMA_STYLES/$theme" ]]; then
        echo "Copying updated theme: $theme"
        cp "$CHROMA_STYLES/$theme" "$TARTRAZINE_STYLES/"
    fi
done

echo ""
echo "=== Sync Complete ==="
echo "Total themes copied: $((3 + ${#updated_themes[@]}))"
