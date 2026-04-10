# Example Output Structure

This document shows what the output directory structure will look like after running the modified ChIP-seq pipeline with the two-stage consensus workflow.

## Sample Dataset

Assume you have the following samples:

```
WT_BCATENIN_IP_REP1_T1.fastq.gz
WT_BCATENIN_IP_REP2_T1.fastq.gz
WT_BCATENIN_IP_REP3_T1.fastq.gz
NAIVE_BCATENIN_IP_REP1_T1.fastq.gz
NAIVE_BCATENIN_IP_REP2_T1.fastq.gz
NAIVE_BCATENIN_IP_REP3_T1.fastq.gz

WT_H3K27AC_IP_REP1_T1.fastq.gz
WT_H3K27AC_IP_REP2_T1.fastq.gz
NAIVE_H3K27AC_IP_REP1_T1.fastq.gz
NAIVE_H3K27AC_IP_REP2_T1.fastq.gz
```

## Expected Output Directory Structure

```
results/
├── consensus_peaks/
│   ├── BCATENIN/                                    # Antibody: BCATENIN
│   │   ├── by_condition/                            # Intermediate consensus files
│   │   │   ├── WT_BCATENIN.bed                      # WT condition consensus (3 reps)
│   │   │   ├── WT_BCATENIN.saf
│   │   │   ├── WT_BCATENIN.boolean.txt
│   │   │   ├── WT_BCATENIN.boolean.intersect.txt
│   │   │   ├── WT_BCATENIN.boolean.intersect.plot.pdf
│   │   │   ├── WT_BCATENIN.condition.txt
│   │   │   ├── NAIVE_BCATENIN.bed                   # NAIVE condition consensus (3 reps)
│   │   │   ├── NAIVE_BCATENIN.saf
│   │   │   ├── NAIVE_BCATENIN.boolean.txt
│   │   │   ├── NAIVE_BCATENIN.boolean.intersect.txt
│   │   │   ├── NAIVE_BCATENIN.boolean.intersect.plot.pdf
│   │   │   └── NAIVE_BCATENIN.condition.txt
│   │   │
│   │   ├── BCATENIN.bed                             # Final consensus (merge of WT + NAIVE)
│   │   ├── BCATENIN.saf
│   │   ├── BCATENIN.boolean.txt
│   │   ├── BCATENIN.boolean.intersect.txt
│   │   ├── BCATENIN.boolean.intersect.plot.pdf
│   │   └── BCATENIN.antibody.txt
│   │
│   └── H3K27AC/                                      # Antibody: H3K27AC
│       ├── by_condition/                             # Intermediate consensus files
│       │   ├── WT_H3K27AC.bed                        # WT condition consensus (2 reps)
│       │   ├── WT_H3K27AC.saf
│       │   ├── WT_H3K27AC.boolean.txt
│       │   ├── WT_H3K27AC.boolean.intersect.txt
│       │   ├── WT_H3K27AC.boolean.intersect.plot.pdf
│       │   ├── WT_H3K27AC.condition.txt
│       │   ├── NAIVE_H3K27AC.bed                     # NAIVE condition consensus (2 reps)
│       │   ├── NAIVE_H3K27AC.saf
│       │   ├── NAIVE_H3K27AC.boolean.txt
│       │   ├── NAIVE_H3K27AC.boolean.intersect.txt
│       │   ├── NAIVE_H3K27AC.boolean.intersect.plot.pdf
│       │   └── NAIVE_H3K27AC.condition.txt
│       │
│       ├── H3K27AC.bed                               # Final consensus (merge of WT + NAIVE)
│       ├── H3K27AC.saf
│       ├── H3K27AC.boolean.txt
│       ├── H3K27AC.boolean.intersect.txt
│       ├── H3K27AC.boolean.intersect.plot.pdf
│       └── H3K27AC.antibody.txt
│
├── macs2/
│   ├── broadPeak/                                    # or narrowPeak
│   │   ├── WT_BCATENIN_IP_REP1_T1_peaks.broadPeak
│   │   ├── WT_BCATENIN_IP_REP2_T1_peaks.broadPeak
│   │   ├── WT_BCATENIN_IP_REP3_T1_peaks.broadPeak
│   │   ├── NAIVE_BCATENIN_IP_REP1_T1_peaks.broadPeak
│   │   ├── NAIVE_BCATENIN_IP_REP2_T1_peaks.broadPeak
│   │   ├── NAIVE_BCATENIN_IP_REP3_T1_peaks.broadPeak
│   │   ├── WT_H3K27AC_IP_REP1_T1_peaks.broadPeak
│   │   ├── WT_H3K27AC_IP_REP2_T1_peaks.broadPeak
│   │   ├── NAIVE_H3K27AC_IP_REP1_T1_peaks.broadPeak
│   │   └── NAIVE_H3K27AC_IP_REP2_T1_peaks.broadPeak
│   │
│   └── qc/
│       └── ... (quality control files)
│
└── ... (other pipeline outputs)
```

## File Descriptions

### Condition-Level Files (in `by_condition/`)

| File | Description |
|------|-------------|
| `*.bed` | Consensus peak regions for the condition (BED6 format) |
| `*.saf` | Simplified annotation format for featureCounts quantification |
| `*.boolean.txt` | Matrix showing which peaks are present in which replicates |
| `*.boolean.intersect.txt` | Intersection statistics between replicates |
| `*.boolean.intersect.plot.pdf` | UpSet plot visualizing peak overlap |
| `*.condition.txt` | Metadata file linking to the BED file |

### Antibody-Level Files (in antibody root directory)

| File | Description |
|------|-------------|
| `*.bed` | Final consensus peak regions across all conditions (BED6 format) |
| `*.saf` | Simplified annotation format for downstream quantification |
| `*.boolean.txt` | Matrix showing which peaks are present in which conditions |
| `*.boolean.intersect.txt` | Intersection statistics between conditions |
| `*.boolean.intersect.plot.pdf` | UpSet plot visualizing peak overlap across conditions |
| `*.antibody.txt` | Metadata file linking to the BED file |

## Example Workflow Trace

### Stage 1: Condition-Level Consensus

**Input**: Individual peak calls
```
WT_BCATENIN_IP_REP1_T1_peaks.broadPeak  (1000 peaks)
WT_BCATENIN_IP_REP2_T1_peaks.broadPeak  (950 peaks)
WT_BCATENIN_IP_REP3_T1_peaks.broadPeak  (1020 peaks)
```

**Process**: MACS2_CONSENSUS_BY_CONDITION
- Merges overlapping peaks
- Applies `params.min_reps_consensus` threshold
- Example: with `min_reps_consensus = 2`, keeps peaks present in ≥2 replicates

**Output**: Condition consensus
```
consensus_peaks/BCATENIN/by_condition/WT_BCATENIN.bed  (800 peaks)
```

### Stage 2: Antibody-Level Consensus

**Input**: Condition consensus files
```
WT_BCATENIN.bed     (800 peaks)
NAIVE_BCATENIN.bed  (750 peaks)
```

**Process**: MACS2_CONSENSUS
- Merges overlapping peaks from conditions
- Applies `params.min_reps_consensus` threshold
- Example: with `min_reps_consensus = 1`, keeps peaks present in ≥1 condition

**Output**: Final antibody consensus
```
consensus_peaks/BCATENIN/BCATENIN.bed  (1200 peaks)
```

## Benefits of This Structure

### 1. Easy Navigation
```bash
# Want all BCATENIN files? Go to one directory
cd consensus_peaks/BCATENIN/

# Want to check condition-level consensus?
cd by_condition/

# Want the final consensus?
ls *.bed  # in BCATENIN/ root
```

### 2. Clear Hierarchy
```
BCATENIN/
├── by_condition/    ← Step 1: Merge replicates
└── *.bed            ← Step 2: Merge conditions
```

### 3. Quality Control
```bash
# Compare condition consensus before final merge
bedtools intersect -a by_condition/WT_BCATENIN.bed \
                   -b by_condition/NAIVE_BCATENIN.bed

# Check how many peaks are condition-specific
bedtools subtract -a by_condition/WT_BCATENIN.bed \
                  -b by_condition/NAIVE_BCATENIN.bed

# Validate final merge includes peaks from both
bedtools intersect -a BCATENIN.bed \
                   -b by_condition/WT_BCATENIN.bed -u | wc -l
```

### 4. Downstream Analysis
```R
# Load all condition-level consensus
bcatenin_conditions <- list.files(
  "consensus_peaks/BCATENIN/by_condition/",
  pattern = "\\.bed$",
  full.names = TRUE
)

# Load final consensus
bcatenin_final <- "consensus_peaks/BCATENIN/BCATENIN.bed"

# Compare condition-specific vs shared peaks
# ... analysis code ...
```

## Parameters That Affect Output

### `params.min_reps_consensus`
Applied at **both** stages:

**Stage 1 (by_condition)**:
- `min_reps_consensus = 2`: Keep peaks in ≥2 replicates per condition
- If condition has 3 replicates, peaks must be in at least 2

**Stage 2 (by_antibody)**:
- `min_reps_consensus = 1`: Keep peaks in ≥1 condition
- With 2 conditions (WT, NAIVE), peaks can be in either condition
- `min_reps_consensus = 2`: Keep only peaks in both conditions

### `params.narrow_peak` vs `params.broad_peak`
Affects:
- Which MACS2 output files are used (narrowPeak vs broadPeak)
- Which columns are merged during consensus
- Peak calling parameters

## Summary

This structure provides:
✅ Clear organization by antibody
✅ Intermediate files for quality control
✅ Easy navigation and file discovery
✅ Traceability from replicates → conditions → antibody
✅ Flexibility for downstream analysis

All files for a given antibody are in one place, making it easy to find, QC, and analyze your results! 🎉
