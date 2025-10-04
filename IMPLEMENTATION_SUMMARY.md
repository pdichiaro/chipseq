# ChIP-seq Pipeline Modifications Summary

## Overview
Modified the consensus peaks workflow to implement a two-stage merge process:
1. **Stage 1**: Create consensus peaks by condition (WT_BCATENIN, NAIVE_BCATENIN, etc.)
2. **Stage 2**: Merge condition-level consensus peaks by antibody for final analysis

## Files Modified

### 1. New Module: `modules/local/macs2_consensus_by_condition.nf`
**Purpose**: Generate consensus peaks at the condition level (intermediate step)

**Key Features**:
- Identical to MACS2_CONSENSUS but publishes to `consensus_peaks/by_condition/`
- Uses the same min_reps_consensus parameter
- Outputs condition-level consensus BED, SAF, and QC files

**Outputs**:
- `*.bed` - Consensus peak regions by condition
- `*.saf` - Annotation format for quantification
- `*.pdf` - Intersection plots
- `*.condition.txt` - Metadata file
- `*.boolean.txt` - Peak presence matrix
- `*.intersect.txt` - Intersection statistics

### 2. Modified Workflow: `workflows/chipseq.nf`

#### Changes Made:

**Added include statement** (line ~99):
```groovy
include { MACS2_CONSENSUS_BY_CONDITION        } from '../modules/local/macs2_consensus_by_condition'
```

**Replaced consensus logic** (lines ~633-695):

**OLD APPROACH** (Single-stage merge):
```
Individual Peaks → Group by Antibody → MACS2_CONSENSUS
```

**NEW APPROACH** (Two-stage merge):
```
Individual Peaks → Group by Condition → MACS2_CONSENSUS_BY_CONDITION
                ↓
    Condition Consensus → Group by Antibody → MACS2_CONSENSUS
```

#### Stage 1: Condition-level consensus
- Extracts group_id by removing `_REP{N}_T{M}` suffix
- Example: `WT_BCATENIN_IP_REP1_T1` → `WT_BCATENIN`
- Groups all replicates within each condition
- Runs MACS2_CONSENSUS_BY_CONDITION
- Publishes to `consensus_peaks/by_condition/`

#### Stage 2: Antibody-level final consensus
- Takes condition-level consensus BED files
- Extracts antibody from condition name
- Example: `WT_BCATENIN` → `BCATENIN`
- Groups all conditions for the same antibody
- Runs MACS2_CONSENSUS (original module)
- Publishes to `consensus_peaks/` (original location)

## Expected Output Structure

```
results/
├── consensus_peaks/
│   ├── by_condition/          # NEW: Intermediate condition-level consensus
│   │   ├── WT_BCATENIN.bed
│   │   ├── WT_BCATENIN.saf
│   │   ├── WT_BCATENIN.pdf
│   │   ├── WT_BCATENIN.condition.txt
│   │   ├── WT_BCATENIN.boolean.txt
│   │   ├── WT_BCATENIN.intersect.txt
│   │   ├── NAIVE_BCATENIN.bed
│   │   ├── NAIVE_BCATENIN.saf
│   │   └── ... (other conditions)
│   │
│   └── BCATENIN/              # EXISTING: Final antibody-level consensus
│       ├── BCATENIN.bed
│       ├── BCATENIN.saf
│       ├── BCATENIN.pdf
│       └── ...
```

## Benefits of This Approach

1. **Hierarchical Merging**: Respects biological grouping (condition → antibody)
2. **Intermediate Files**: Condition-level consensus files available for inspection
3. **Quality Control**: Can QC condition-level consensus before final merge
4. **Flexibility**: Can apply different merge thresholds at each stage
5. **Traceability**: Clear lineage from individual peaks → condition consensus → antibody consensus

## Parameters Affected

- `params.min_reps_consensus`: Applied at BOTH stages
  - Stage 1: Minimum replicates within a condition
  - Stage 2: Minimum conditions for antibody consensus

## Testing Recommendations

1. Verify condition-level consensus files are created in `by_condition/` directory
2. Check that antibody-level consensus correctly merges conditions
3. Validate that meta.multiple_groups flag is correctly set
4. Ensure output file naming follows expected patterns

## Next Steps

1. Test with full dataset to verify channel logic
2. Consider adding parameter for condition-level min_reps vs antibody-level
3. Add condition comparison analysis downstream
4. Document in pipeline documentation
