# Migration Guide: Samplesheet Format Update

## Overview

This guide helps you migrate existing samplesheets to the new nf-core standard format with explicit replicate columns.

## What Changed?

### Input Format

**Before** (6 required columns):
```csv
sample,fastq_1,fastq_2,antibody,control
```

**After** (7 required columns):
```csv
sample,fastq_1,fastq_2,replicate,antibody,control,control_replicate
```

### Output Format

The validated output (`samplesheet.valid.csv`) now includes an additional `replicate` column:

**Before** (6 columns):
```csv
sample,single_end,fastq_1,fastq_2,antibody,control
```

**After** (7 columns):
```csv
sample,single_end,fastq_1,fastq_2,replicate,antibody,control
```

## Sample Naming: No Change! ✅

**Important**: The final sample names remain **identical**:
- Before: `WT_BCATENIN_IP_REP1_T1`
- After: `WT_BCATENIN_IP_REP1_T1`

## Migration Steps

### Step 1: Identify Your Current Format

**Old format example**:
```csv
sample,fastq_1,fastq_2,antibody,control
WT_BCATENIN_IP_REP1,IP_rep1_R1.fq.gz,IP_rep1_R2.fq.gz,BCATENIN,WT_INPUT_REP1
WT_BCATENIN_IP_REP2,IP_rep2_R1.fq.gz,IP_rep2_R2.fq.gz,BCATENIN,WT_INPUT_REP2
WT_INPUT_REP1,input_rep1_R1.fq.gz,input_rep1_R2.fq.gz,,
WT_INPUT_REP2,input_rep2_R1.fq.gz,input_rep2_R2.fq.gz,,
```

### Step 2: Remove `_REP{N}` from Sample Names

Extract the base sample name by removing the replicate suffix:
- `WT_BCATENIN_IP_REP1` → `WT_BCATENIN_IP`
- `WT_INPUT_REP1` → `WT_INPUT`

### Step 3: Add `replicate` Column

Add the replicate number as a separate column:
- `WT_BCATENIN_IP_REP1` → sample: `WT_BCATENIN_IP`, replicate: `1`
- `WT_BCATENIN_IP_REP2` → sample: `WT_BCATENIN_IP`, replicate: `2`

### Step 4: Add `control_replicate` Column

For each control, add the replicate number:
- If control is `WT_INPUT_REP1` → control: `WT_INPUT`, control_replicate: `1`
- If control is empty → control_replicate: empty

### Step 5: Complete Migration

**New format**:
```csv
sample,fastq_1,fastq_2,replicate,antibody,control,control_replicate
WT_BCATENIN_IP,IP_rep1_R1.fq.gz,IP_rep1_R2.fq.gz,1,BCATENIN,WT_INPUT,1
WT_BCATENIN_IP,IP_rep2_R1.fq.gz,IP_rep2_R2.fq.gz,2,BCATENIN,WT_INPUT,2
WT_INPUT,input_rep1_R1.fq.gz,input_rep1_R2.fq.gz,1,,,
WT_INPUT,input_rep2_R1.fq.gz,input_rep2_R2.fq.gz,2,,,
```

## Example Conversions

### Example 1: Basic ChIP-seq with Controls

**Before**:
```csv
sample,fastq_1,fastq_2,antibody,control
SPT5_T0_REP1,SRR1822153_1.fastq.gz,SRR1822153_2.fastq.gz,SPT5,SPT5_INPUT_REP1
SPT5_T0_REP2,SRR1822154_1.fastq.gz,SRR1822154_2.fastq.gz,SPT5,SPT5_INPUT_REP2
SPT5_INPUT_REP1,SRR5204809_R1.fastq.gz,SRR5204809_R2.fastq.gz,,
SPT5_INPUT_REP2,SRR5204810_R1.fastq.gz,SRR5204810_R2.fastq.gz,,
```

**After**:
```csv
sample,fastq_1,fastq_2,replicate,antibody,control,control_replicate
SPT5_T0,SRR1822153_1.fastq.gz,SRR1822153_2.fastq.gz,1,SPT5,SPT5_INPUT,1
SPT5_T0,SRR1822154_1.fastq.gz,SRR1822154_2.fastq.gz,2,SPT5,SPT5_INPUT,2
SPT5_INPUT,SRR5204809_R1.fastq.gz,SRR5204809_R2.fastq.gz,1,,,
SPT5_INPUT,SRR5204810_R1.fastq.gz,SRR5204810_R2.fastq.gz,2,,,
```

### Example 2: Multiple Technical Replicates (Same Replicate, Different Lanes)

**Before**:
```csv
sample,fastq_1,fastq_2,antibody,control
WT_IP_REP1,IP_rep1_lane1_R1.fq.gz,IP_rep1_lane1_R2.fq.gz,H3K27AC,WT_INPUT_REP1
WT_IP_REP1,IP_rep1_lane2_R1.fq.gz,IP_rep1_lane2_R2.fq.gz,H3K27AC,WT_INPUT_REP1
WT_INPUT_REP1,input_rep1_lane1_R1.fq.gz,input_rep1_lane1_R2.fq.gz,,
WT_INPUT_REP1,input_rep1_lane2_R1.fq.gz,input_rep1_lane2_R2.fq.gz,,
```

**After**:
```csv
sample,fastq_1,fastq_2,replicate,antibody,control,control_replicate
WT_IP,IP_rep1_lane1_R1.fq.gz,IP_rep1_lane1_R2.fq.gz,1,H3K27AC,WT_INPUT,1
WT_IP,IP_rep1_lane2_R1.fq.gz,IP_rep1_lane2_R2.fq.gz,1,H3K27AC,WT_INPUT,1
WT_INPUT,input_rep1_lane1_R1.fq.gz,input_rep1_lane1_R2.fq.gz,1,,,
WT_INPUT,input_rep1_lane2_R1.fq.gz,input_rep1_lane2_R2.fq.gz,1,,,
```

**Note**: Multiple rows with the same `sample` and `replicate` are technical replicates (e.g., different sequencing lanes). They will be merged during alignment.

### Example 3: Single-End Data

**Before**:
```csv
sample,fastq_1,fastq_2,antibody,control
MUT_H3K4ME3_REP1,IP_rep1.fq.gz,,H3K4ME3,MUT_INPUT_REP1
MUT_H3K4ME3_REP2,IP_rep2.fq.gz,,H3K4ME3,MUT_INPUT_REP2
MUT_INPUT_REP1,input_rep1.fq.gz,,,,
MUT_INPUT_REP2,input_rep2.fq.gz,,,,
```

**After**:
```csv
sample,fastq_1,fastq_2,replicate,antibody,control,control_replicate
MUT_H3K4ME3,IP_rep1.fq.gz,,1,H3K4ME3,MUT_INPUT,1
MUT_H3K4ME3,IP_rep2.fq.gz,,2,H3K4ME3,MUT_INPUT,2
MUT_INPUT,input_rep1.fq.gz,,1,,,
MUT_INPUT,input_rep2.fq.gz,,2,,,
```

### Example 4: No Control Matching (Input-Only)

**Before**:
```csv
sample,fastq_1,fastq_2,antibody,control
WT_CTCF_REP1,IP_rep1_R1.fq.gz,IP_rep1_R2.fq.gz,CTCF,
WT_CTCF_REP2,IP_rep2_R1.fq.gz,IP_rep2_R2.fq.gz,CTCF,
WT_INPUT_REP1,input_rep1_R1.fq.gz,input_rep1_R2.fq.gz,,
WT_INPUT_REP2,input_rep2_R1.fq.gz,input_rep2_R2.fq.gz,,
```

**After**:
```csv
sample,fastq_1,fastq_2,replicate,antibody,control,control_replicate
WT_CTCF,IP_rep1_R1.fq.gz,IP_rep1_R2.fq.gz,1,CTCF,,
WT_CTCF,IP_rep2_R1.fq.gz,IP_rep2_R2.fq.gz,2,CTCF,,
WT_INPUT,input_rep1_R1.fq.gz,input_rep1_R2.fq.gz,1,,,
WT_INPUT,input_rep2_R1.fq.gz,input_rep2_R2.fq.gz,2,,,
```

## Automated Migration Script

For large samplesheets, you can use this Python script to automate the migration:

```python
#!/usr/bin/env python3
import csv
import re
import sys

def migrate_samplesheet(input_file, output_file):
    """
    Migrate old format samplesheet to new nf-core format
    """
    with open(input_file, 'r') as fin, open(output_file, 'w', newline='') as fout:
        reader = csv.DictReader(fin)
        
        # Check if already in new format
        if 'replicate' in reader.fieldnames:
            print("Warning: Samplesheet already in new format!")
            sys.exit(1)
        
        # New header
        writer = csv.DictWriter(fout, fieldnames=[
            'sample', 'fastq_1', 'fastq_2', 'replicate', 
            'antibody', 'control', 'control_replicate'
        ])
        writer.writeheader()
        
        for row in reader:
            # Extract replicate from sample name
            match = re.search(r'_REP(\d+)$', row['sample'])
            if match:
                replicate = match.group(1)
                base_sample = re.sub(r'_REP\d+$', '', row['sample'])
            else:
                # No replicate suffix, assume replicate 1
                replicate = '1'
                base_sample = row['sample']
            
            # Extract control replicate
            control = row.get('control', '')
            control_replicate = ''
            if control:
                control_match = re.search(r'_REP(\d+)$', control)
                if control_match:
                    control_replicate = control_match.group(1)
                    control = re.sub(r'_REP\d+$', '', control)
            
            # Write new row
            writer.writerow({
                'sample': base_sample,
                'fastq_1': row['fastq_1'],
                'fastq_2': row.get('fastq_2', ''),
                'replicate': replicate,
                'antibody': row.get('antibody', ''),
                'control': control,
                'control_replicate': control_replicate
            })
    
    print(f"Migration complete: {input_file} → {output_file}")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python migrate_samplesheet.py <input.csv> <output.csv>")
        sys.exit(1)
    
    migrate_samplesheet(sys.argv[1], sys.argv[2])
```

**Usage**:
```bash
python migrate_samplesheet.py old_samplesheet.csv new_samplesheet.csv
```

## Validation

After migration, validate your new samplesheet:

```bash
python bin/check_samplesheet.py new_samplesheet.csv samplesheet.valid.csv
```

If successful, you should see no errors and a `samplesheet.valid.csv` file will be generated.

## Workflow Compatibility

**Important**: The workflow is fully compatible with both formats at the output level:
- Sample names remain identical: `{sample}_REP{n}_T{m}`
- All downstream processing works unchanged
- The new `replicate` column is available but currently unused by the workflow

Future workflow improvements may leverage the explicit replicate column for better grouping and processing logic.

## Troubleshooting

### Error: "Replicate ids must start with 1"
Ensure replicates are numbered sequentially starting from 1 (e.g., 1, 2, 3).

### Error: "Control identifier and replicate has to match"
Check that:
1. The control sample name exists in the samplesheet
2. The control replicate number matches an existing replicate for that control

### Multiple entries with same sample and replicate
This is **allowed** and indicates technical replicates (multiple lanes/runs). They will be merged automatically.

### Sample names with spaces
Spaces are automatically replaced with underscores. Review the output to ensure names are as expected.

## Need Help?

- Full format specification: [docs/samplesheet_format.md](samplesheet_format.md)
- Pipeline usage: [docs/usage.md](usage.md)
- nf-core ChIP-seq examples: https://github.com/nf-core/test-datasets/tree/chipseq/samplesheet/v2.1

## Summary

| Aspect | Change | Impact |
|--------|--------|--------|
| **Input columns** | 6 → 7 | Add `replicate` and `control_replicate` |
| **Output columns** | 6 → 7 | Add `replicate` column |
| **Sample naming** | No change | Still `{sample}_REP{n}_T{m}` |
| **Workflow logic** | No change | Compatible, replicate column unused |
| **Validation** | Improved | Better error messages, replicate checking |

**Migration is straightforward**: Remove `_REP{N}` from sample names, add explicit replicate columns. The rest stays the same! ✅
