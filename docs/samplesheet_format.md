# Samplesheet Format

## Overview

This pipeline uses an improved samplesheet validation script based on the nf-core ChIP-seq standard. The script provides better error messages and explicit replicate tracking.

## Required Format

The input samplesheet must be a CSV file with the following columns:

```csv
sample,fastq_1,fastq_2,replicate,antibody,control,control_replicate
```

### Column Descriptions

| Column | Required | Description |
|--------|----------|-------------|
| `sample` | Yes | Unique sample identifier (base name, without replicate suffix) |
| `fastq_1` | Yes | Path to Read 1 FASTQ file (`.fastq.gz` or `.fq.gz`) |
| `fastq_2` | No | Path to Read 2 FASTQ file (leave empty for single-end) |
| `replicate` | Yes | Replicate number (integer starting from 1) |
| `antibody` | No | Antibody name (required for IP samples, empty for inputs) |
| `control` | No | Sample name of the corresponding input control |
| `control_replicate` | No | Replicate number of the control (required if control is specified) |

## Example Samplesheets

### Paired-End ChIP-seq with Replicates

```csv
sample,fastq_1,fastq_2,replicate,antibody,control,control_replicate
WT_BCATENIN_IP,data/IP_rep1_R1.fq.gz,data/IP_rep1_R2.fq.gz,1,BCATENIN,WT_INPUT,1
WT_BCATENIN_IP,data/IP_rep2_R1.fq.gz,data/IP_rep2_R2.fq.gz,2,BCATENIN,WT_INPUT,2
WT_INPUT,data/input_rep1_R1.fq.gz,data/input_rep1_R2.fq.gz,1,,,
WT_INPUT,data/input_rep2_R1.fq.gz,data/input_rep2_R2.fq.gz,2,,,
```

**Output after validation** (`samplesheet.valid.csv`):
```csv
sample,single_end,fastq_1,fastq_2,replicate,antibody,control
WT_BCATENIN_IP_REP1_T1,0,data/IP_rep1_R1.fq.gz,data/IP_rep1_R2.fq.gz,1,BCATENIN,WT_INPUT_REP1
WT_BCATENIN_IP_REP2_T1,0,data/IP_rep2_R1.fq.gz,data/IP_rep2_R2.fq.gz,2,BCATENIN,WT_INPUT_REP2
WT_INPUT_REP1_T1,0,data/input_rep1_R1.fq.gz,data/input_rep1_R2.fq.gz,1,,
WT_INPUT_REP2_T1,0,data/input_rep2_R1.fq.gz,data/input_rep2_R2.fq.gz,2,,
```

### Multiple Technical Replicates

If you have multiple sequencing runs (lanes) for the same biological replicate:

```csv
sample,fastq_1,fastq_2,replicate,antibody,control,control_replicate
WT_BCATENIN_IP,data/IP_rep1_lane1_R1.fq.gz,data/IP_rep1_lane1_R2.fq.gz,1,BCATENIN,WT_INPUT,1
WT_BCATENIN_IP,data/IP_rep1_lane2_R1.fq.gz,data/IP_rep1_lane2_R2.fq.gz,1,BCATENIN,WT_INPUT,1
WT_INPUT,data/input_rep1_lane1_R1.fq.gz,data/input_rep1_lane1_R2.fq.gz,1,,,
WT_INPUT,data/input_rep1_lane2_R1.fq.gz,data/input_rep1_lane2_R2.fq.gz,1,,,
```

**Output after validation**:
```csv
sample,single_end,fastq_1,fastq_2,replicate,antibody,control
WT_BCATENIN_IP_REP1_T1,0,data/IP_rep1_lane1_R1.fq.gz,data/IP_rep1_lane1_R2.fq.gz,1,BCATENIN,WT_INPUT_REP1
WT_BCATENIN_IP_REP1_T2,0,data/IP_rep1_lane2_R1.fq.gz,data/IP_rep1_lane2_R2.fq.gz,1,BCATENIN,WT_INPUT_REP1
WT_INPUT_REP1_T1,0,data/input_rep1_lane1_R1.fq.gz,data/input_rep1_lane1_R2.fq.gz,1,,
WT_INPUT_REP1_T2,0,data/input_rep1_lane2_R1.fq.gz,data/input_rep1_lane2_R2.fq.gz,1,,
```

Note: Technical replicates (multiple lanes) are automatically merged during alignment.

### Single-End Data

For single-end sequencing, leave `fastq_2` empty:

```csv
sample,fastq_1,fastq_2,replicate,antibody,control,control_replicate
WT_H3K4ME3_IP,data/IP_rep1.fq.gz,,1,H3K4ME3,WT_INPUT,1
WT_H3K4ME3_IP,data/IP_rep2.fq.gz,,2,H3K4ME3,WT_INPUT,2
WT_INPUT,data/input_rep1.fq.gz,,1,,,
WT_INPUT,data/input_rep2.fq.gz,,2,,,
```

### Input-Only Controls (No Specific IP-Input Pairing)

For input controls without specific pairing:

```csv
sample,fastq_1,fastq_2,replicate,antibody,control,control_replicate
WT_BCATENIN_IP,data/IP_rep1_R1.fq.gz,data/IP_rep1_R2.fq.gz,1,BCATENIN,,
WT_BCATENIN_IP,data/IP_rep2_R1.fq.gz,data/IP_rep2_R2.fq.gz,2,BCATENIN,,
WT_INPUT,data/input_rep1_R1.fq.gz,data/input_rep1_R2.fq.gz,1,,,
WT_INPUT,data/input_rep2_R1.fq.gz,data/input_rep2_R2.fq.gz,2,,,
```

## Validation Rules

The samplesheet validation script enforces the following rules:

### Sample Names
- Must not contain spaces (automatically replaced with underscores)
- Must be unique within the combination of sample + replicate
- Cannot be empty

### FASTQ Files
- Must have extension `.fastq.gz` or `.fq.gz`
- Must not contain spaces in file paths
- `fastq_1` is required for all samples
- `fastq_2` is optional (for single-end data)

### Replicates
- Must be integers starting from 1
- Must be sequential: 1, 2, 3, ... (no gaps)
- All replicates of the same sample must use the same data type (single-end or paired-end)
- All technical replicates (same sample + replicate, different rows) must use the same data type

### Antibody and Controls
- If `antibody` is specified, it identifies the sample as an IP sample
- If `antibody` is empty, the sample is treated as an input control
- If `control` is specified, `control_replicate` must also be specified
- Control identifiers must match existing sample names
- Control replicates must match existing replicate numbers

### Multiple Runs (Technical Replicates)
- Multiple rows with the same `sample` and `replicate` are treated as technical replicates
- Technical replicates are automatically merged during the alignment step
- Sample names in the validated output are appended with `_T1`, `_T2`, etc.

## Sample Naming Convention

The validation script generates standardized sample names in the output:

**Format**: `{sample}_REP{replicate}_T{technical_replicate}`

**Examples**:
- Input: `WT_BCATENIN_IP` (replicate 1, first technical replicate) → Output: `WT_BCATENIN_IP_REP1_T1`
- Input: `WT_BCATENIN_IP` (replicate 2, first technical replicate) → Output: `WT_BCATENIN_IP_REP2_T1`
- Input: `WT_INPUT` (replicate 1, second technical replicate/lane) → Output: `WT_INPUT_REP1_T2`

## Troubleshooting

### Error: "Invalid number of columns"
Check that your CSV has exactly 7 columns and no trailing commas.

### Error: "Replicate ids must start with 1"
Replicates must be numbered sequentially starting from 1. If you have replicates 2 and 3, you must also have replicate 1.

### Error: "Control identifier and replicate has to match"
Make sure:
1. The `control` column contains a valid sample name that exists in the samplesheet
2. The `control_replicate` column contains a valid replicate number for that control sample

### Error: "Multiple replicates of a sample must be of the same datatype"
All replicates of the same sample must be either all single-end (no `fastq_2`) or all paired-end (with `fastq_2`).

### Warning: "Spaces have been replaced by underscores"
Spaces in sample names or antibody names are automatically replaced with underscores. Check the output to ensure the names are as expected.

## Migration from Old Format

If you're migrating from the old samplesheet format (without explicit replicate columns):

**Old format**:
```csv
sample,fastq_1,fastq_2,antibody,control
WT_BCATENIN_IP_REP1,IP_rep1_R1.fq.gz,IP_rep1_R2.fq.gz,BCATENIN,WT_INPUT_REP1
```

**New format**:
```csv
sample,fastq_1,fastq_2,replicate,antibody,control,control_replicate
WT_BCATENIN_IP,IP_rep1_R1.fq.gz,IP_rep1_R2.fq.gz,1,BCATENIN,WT_INPUT,1
```

**Key differences**:
1. Remove `_REP{N}` suffix from sample names
2. Add explicit `replicate` column with integer values
3. Add `control_replicate` column matching the control's replicate number
4. The pipeline output will have identical sample naming (`{sample}_REP{n}_T{m}`)

## More Information

- For full pipeline usage instructions, see [docs/usage.md](usage.md)
- For output file descriptions, see [docs/output.md](output.md)
- For nf-core ChIP-seq samplesheet examples, see: https://github.com/nf-core/test-datasets/tree/chipseq/samplesheet/v2.1
