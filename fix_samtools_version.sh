#!/bin/bash

# Fix samtools version extraction in all modules
# Replace the problematic pattern with the correct one

files=(
  "modules/local/blacklist_log.nf"
  "modules/local/frip_score.nf"
  "modules/nf-core/modules/bowtie2/align/main.nf"
  "modules/nf-core/modules/custom/getchromsizes/main.nf"
  "modules/nf-core/modules/samtools/flagstat/main.nf"
  "modules/nf-core/modules/samtools/idxstats/main.nf"
  "modules/nf-core/modules/samtools/index/main.nf"
  "modules/nf-core/modules/samtools/sort/main.nf"
  "modules/nf-core/modules/samtools/stats/main.nf"
)

for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    echo "Fixing $file..."
    # Use perl for in-place editing to handle the complex escape sequences
    perl -i -pe 's/\$\(echo \$\(samtools --version 2>&1\) \| sed '\''s\/\^\.\*samtools \/\/; s\/Using\.\*\$\/\/'\'')/\$(samtools --version 2>\&1 | head -n1 | sed '\''s\/^samtools \/\/'\'')/g' "$file"
  else
    echo "File not found: $file"
  fi
done

echo "Done!"
