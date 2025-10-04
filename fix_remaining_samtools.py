#!/usr/bin/env python3

import re

# List of remaining files to fix
files = [
    "modules/nf-core/modules/custom/getchromsizes/main.nf",
    "modules/nf-core/modules/samtools/flagstat/main.nf",
    "modules/nf-core/modules/samtools/idxstats/main.nf",
    "modules/nf-core/modules/samtools/index/main.nf",
    "modules/nf-core/modules/samtools/sort/main.nf",
    "modules/nf-core/modules/samtools/stats/main.nf",
]

# Pattern to match (with proper escaping)
old_pattern = r'\$\(echo \$\(samtools --version 2>&1\) \| sed \'s/\^\.\*samtools //; s/Using\.\*\$//\'\)'
new_pattern = r'$(samtools --version 2>&1 | head -n1 | sed \'s/^samtools //\')'

for filepath in files:
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        
        # Count occurrences
        count = content.count(r"$(echo $(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*$//')")
        
        if count > 0:
            # Replace
            new_content = content.replace(
                r"$(echo $(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*$//')",
                r"$(samtools --version 2>&1 | head -n1 | sed 's/^samtools //')"
            )
            
            with open(filepath, 'w') as f:
                f.write(new_content)
            
            print(f"✓ Fixed {filepath} ({count} occurrence(s))")
        else:
            print(f"  Skipped {filepath} (already fixed or pattern not found)")
            
    except FileNotFoundError:
        print(f"✗ File not found: {filepath}")
    except Exception as e:
        print(f"✗ Error processing {filepath}: {e}")

print("\nDone!")
