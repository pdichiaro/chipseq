#!/bin/bash

# Fix remaining samtools modules using sed in-place

files=(
  "modules/nf-core/modules/samtools/idxstats/main.nf"
  "modules/nf-core/modules/samtools/index/main.nf"
  "modules/nf-core/modules/samtools/sort/main.nf"
  "modules/nf-core/modules/samtools/stats/main.nf"
)

for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    echo "Processing $file..."
    # Use sed with a simpler approach - replace the whole samtools version line
    sed -i "s/samtools: \\\\\$(echo \\\\\$(samtools --version 2>&1) | sed 's\/\^.\*samtools \/\/; s\/Using.\*\$\/\/')/samtools: \\\\\$(samtools --version 2>\&1 | head -n1 | sed 's\/^samtools \/\/')/g" "$file"
    echo "  ✓ Fixed"
  else
    echo "  ✗ File not found: $file"
  fi
done

echo "Done!"
