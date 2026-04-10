# Consensus Peaks Workflow - Directory Structure

## Visual Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                    Individual Peak Calls                     │
│                    (from MACS2_CALLPEAK)                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ├─── WT_BCATENIN_IP_REP1_T1.narrowPeak
                              ├─── WT_BCATENIN_IP_REP2_T1.narrowPeak
                              ├─── WT_BCATENIN_IP_REP3_T1.narrowPeak
                              ├─── NAIVE_BCATENIN_IP_REP1_T1.narrowPeak
                              ├─── NAIVE_BCATENIN_IP_REP2_T1.narrowPeak
                              └─── NAIVE_BCATENIN_IP_REP3_T1.narrowPeak
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              STAGE 1: Group by Condition                     │
│         (Remove _REP{N}_T{M} suffix from IDs)               │
└─────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
                    ▼                   ▼
         ┌──────────────────┐  ┌──────────────────┐
         │  WT_BCATENIN     │  │ NAIVE_BCATENIN   │
         │  (3 replicates)  │  │  (3 replicates)  │
         └──────────────────┘  └──────────────────┘
                    │                   │
                    ▼                   ▼
         ┌──────────────────┐  ┌──────────────────┐
         │ MACS2_CONSENSUS_ │  │ MACS2_CONSENSUS_ │
         │   BY_CONDITION   │  │   BY_CONDITION   │
         └──────────────────┘  └──────────────────┘
                    │                   │
                    ▼                   ▼
         ┌──────────────────────────────────────┐
         │      OUTPUT DIRECTORY STRUCTURE       │
         │                                       │
         │  consensus_peaks/                     │
         │  └── BCATENIN/                        │
         │      └── by_condition/                │
         │          ├── WT_BCATENIN.bed          │
         │          ├── WT_BCATENIN.saf          │
         │          ├── WT_BCATENIN.pdf          │
         │          ├── WT_BCATENIN.*.txt        │
         │          ├── NAIVE_BCATENIN.bed       │
         │          ├── NAIVE_BCATENIN.saf       │
         │          ├── NAIVE_BCATENIN.pdf       │
         │          └── NAIVE_BCATENIN.*.txt     │
         └──────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│           STAGE 2: Group by Antibody                         │
│     (Extract antibody from condition name: last part)        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │    BCATENIN      │
                    │  (2 conditions)  │
                    └──────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │ MACS2_CONSENSUS  │
                    │ (Final Merge)    │
                    └──────────────────┘
                              │
                              ▼
         ┌──────────────────────────────────────┐
         │      FINAL OUTPUT STRUCTURE           │
         │                                       │
         │  consensus_peaks/                     │
         │  └── BCATENIN/                        │
         │      ├── by_condition/  ← (above)     │
         │      ├── BCATENIN.bed                 │
         │      ├── BCATENIN.saf                 │
         │      ├── BCATENIN.pdf                 │
         │      ├── BCATENIN.boolean.txt         │
         │      └── BCATENIN.*.txt               │
         └──────────────────────────────────────┘
```

## Key Features

### 1. **Hierarchical Organization**
All files for an antibody are contained in `consensus_peaks/{ANTIBODY}/`:
- `by_condition/` subdirectory: Intermediate consensus for each condition
- Root directory: Final consensus across all conditions

### 2. **Two-Stage Merging**
- **Stage 1**: Merge replicates within each condition
  - Input: Individual peak files per replicate
  - Output: One consensus file per condition (WT_BCATENIN, NAIVE_BCATENIN, etc.)
  
- **Stage 2**: Merge conditions for each antibody
  - Input: Condition-level consensus files
  - Output: One final consensus file per antibody (BCATENIN)

### 3. **Biological Grouping**
The structure respects biological relationships:
```
ANTIBODY (BCATENIN)
  ├── CONDITION 1 (WT_BCATENIN)
  │   ├── Replicate 1
  │   ├── Replicate 2
  │   └── Replicate 3
  │
  └── CONDITION 2 (NAIVE_BCATENIN)
      ├── Replicate 1
      ├── Replicate 2
      └── Replicate 3
```

## Example with Multiple Antibodies

```
consensus_peaks/
├── BCATENIN/
│   ├── by_condition/
│   │   ├── WT_BCATENIN.bed
│   │   ├── WT_BCATENIN.saf
│   │   ├── NAIVE_BCATENIN.bed
│   │   └── NAIVE_BCATENIN.saf
│   ├── BCATENIN.bed          # Final merge
│   └── BCATENIN.saf
│
├── H3K27AC/
│   ├── by_condition/
│   │   ├── WT_H3K27AC.bed
│   │   ├── WT_H3K27AC.saf
│   │   ├── NAIVE_H3K27AC.bed
│   │   └── NAIVE_H3K27AC.saf
│   ├── H3K27AC.bed           # Final merge
│   └── H3K27AC.saf
│
└── H3K4ME3/
    ├── by_condition/
    │   ├── WT_H3K4ME3.bed
    │   ├── NAIVE_H3K4ME3.bed
    │   └── KO_H3K4ME3.bed
    ├── H3K4ME3.bed            # Final merge
    └── H3K4ME3.saf
```

## Benefits

✅ **Logical Organization**: All files for an antibody are in one place
✅ **Clear Hierarchy**: Intermediate (by condition) vs final (by antibody) files
✅ **Easy Navigation**: Find all related files in antibody subdirectory
✅ **Traceability**: Can trace from individual replicate → condition consensus → antibody consensus
✅ **Quality Control**: Can QC each condition before final merge
✅ **Flexibility**: Can apply different thresholds at each stage

## Parameters Applied

- `params.min_reps_consensus`: Minimum replicates required at **both** stages
  - Stage 1: Minimum replicates per condition
  - Stage 2: Minimum conditions per antibody (if multiple_groups = true)

## File Types Generated

For each consensus (both by_condition and final):
- `.bed` - Peak regions in BED format
- `.saf` - Simplified annotation format for featureCounts
- `.pdf` - UpSet plot showing peak overlap
- `.boolean.txt` - Peak presence/absence matrix
- `.intersect.txt` - Intersection statistics
- `.condition.txt` or `.antibody.txt` - Metadata file
