# Two-Level Consensus Peak Calling

## Overview

This pipeline implements a two-level consensus approach for peak calling to handle experimental designs with multiple biological replicates across different conditions.

## The Problem

Consider an experimental design like:
```
Antibody: BCATENIN
  Condition: WT
    - WT_BCATENIN_REP1
    - WT_BCATENIN_REP2
  Condition: NAIVE
    - NAIVE_BCATENIN_REP1
    - NAIVE_BCATENIN_REP2
```

We want to:
1. **First**, create consensus peaks **within each condition** (across biological replicates)
2. **Then**, merge consensus peaks **across conditions** (for the same antibody)

## Implementation

### Level 1: Consensus by Condition (MACS2_CONSENSUS_BY_CONDITION)

**Input**: Peaks from biological replicates of the same condition
- `WT_BCATENIN_REP1_peaks.narrowPeak`
- `WT_BCATENIN_REP2_peaks.narrowPeak`

**Process**:
- Groups peaks by condition (e.g., `WT_BCATENIN`)
- Applies `min_reps_consensus` filter (default: 2)
- **Only retains peaks present in at least 2 biological replicates**

**Output**: 
- `WT_BCATENIN_peaks.narrowPeak` (consensus across WT replicates)
- `NAIVE_BCATENIN_peaks.narrowPeak` (consensus across NAIVE replicates)

### Level 2: Consensus by Antibody (MACS2_CONSENSUS)

**Input**: Condition-level consensus peaks
- `WT_BCATENIN_peaks.narrowPeak`
- `NAIVE_BCATENIN_peaks.narrowPeak`

**Process**:
- Groups peaks by antibody (e.g., `BCATENIN`)
- Automatically sets `min_replicates = 1` (via `meta.replicates_exist = true`)
- **Merges all condition-level peaks** (no additional filtering)

**Output**:
- `BCATENIN.bed` (final consensus across all conditions)

## Key Implementation Details

### Automatic min_replicates Adjustment

The `MACS2_CONSENSUS` module automatically adjusts the minimum replicates requirement:

```groovy
def min_reps = meta.replicates_exist ? 1 : params.min_reps_consensus
```

- **When `meta.replicates_exist = true`**: Input peaks are already filtered consensus from replicates → use `min_reps = 1` (keep all)
- **When `meta.replicates_exist = false`**: Input peaks are from individual samples → use `min_reps = params.min_reps_consensus` (default: 2)

### Metadata Flow

```groovy
// Level 1: By condition
meta_new.antibody = antibody              // e.g., "BCATENIN"
meta_new.condition = condition            // e.g., "WT"
meta_new.id = "${condition}_${antibody}"  // e.g., "WT_BCATENIN"
meta_new.multiple_groups = replicate_ids.size() > 1

// Level 2: By antibody
meta_new.id = antibody                    // e.g., "BCATENIN"
meta_new.multiple_groups = group_ids.size() > 1
meta_new.replicates_exist = true          // KEY: Signals that inputs are already consensus
```

## Benefits

1. **Robust within-condition peaks**: Only peaks reproducible across biological replicates are retained
2. **Comprehensive cross-condition view**: All reproducible peaks from any condition are included in final antibody consensus
3. **Flexible filtering**: Users can filter final peaks by condition presence using the boolean matrix
4. **Automatic behavior**: The pipeline automatically applies appropriate filtering at each level

## Configuration

### Parameters

- `min_reps_consensus`: Minimum replicates for level 1 consensus (default: 2)
  - Automatically set to 1 for level 2 (antibody merging)
  
### Example

With `min_reps_consensus = 2`:

```
WT_BCATENIN_REP1: Peak A, Peak B, Peak C
WT_BCATENIN_REP2: Peak A, Peak B, Peak D

NAIVE_BCATENIN_REP1: Peak B, Peak E, Peak F
NAIVE_BCATENIN_REP2: Peak B, Peak E, Peak G

Level 1 consensus (min_reps=2):
  WT_BCATENIN:    Peak A, Peak B (present in 2/2 WT replicates)
  NAIVE_BCATENIN: Peak B, Peak E (present in 2/2 NAIVE replicates)

Level 2 consensus (min_reps=1):
  BCATENIN: Peak A, Peak B, Peak E (union of all condition consensus peaks)
```

## Downstream Analysis

The final `BCATENIN.boolean.txt` includes columns for each condition, allowing filtering like:

```R
# Peaks present in both WT and NAIVE
peaks_shared <- peaks[peaks$WT_BCATENIN == 1 & peaks$NAIVE_BCATENIN == 1, ]

# Peaks specific to WT
peaks_wt_specific <- peaks[peaks$WT_BCATENIN == 1 & peaks$NAIVE_BCATENIN == 0, ]
```

## Workflow Path

```
Individual Samples (e.g., WT_BCATENIN_REP1, WT_BCATENIN_REP2)
          ↓
    MACS2 Peak Calling
          ↓
[LEVEL 1] MACS2_CONSENSUS_BY_CONDITION (min_reps = params.min_reps_consensus)
          ↓
  Condition Consensus (e.g., WT_BCATENIN, NAIVE_BCATENIN)
          ↓
[LEVEL 2] MACS2_CONSENSUS (min_reps = 1, auto-detected via meta.replicates_exist)
          ↓
  Antibody Consensus (e.g., BCATENIN)
          ↓
  Homer Annotation & Boolean Matrix
          ↓
    Downstream Analysis
```
