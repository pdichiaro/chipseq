# Fix for plot_peak_intersect.r Error

## Problem
The `plot_peak_intersect.r` script was failing in the MACS2_CONSENSUS process with error:
```
Error in colSums(temp_data): 'x' must be an array of at least two dimensions
```

## Root Cause
After implementing the two-level consensus system:
1. **Individual samples** → MACS2_CALLPEAK_SINGLE (e.g., 6-8 samples per antibody)
2. **By condition** → MACS2_CONSENSUS_BY_CONDITION (e.g., WT_BCATENIN, NAIVE_BCATENIN)
3. **By antibody** → MACS2_CONSENSUS (merges 2-3 condition consensus files)

The final MACS2_CONSENSUS step was trying to create an UpSet plot with only 2-3 input files (condition consensus peaks), which doesn't have enough dimensions for the R UpSet plot.

## Solution: Two Separate Plots

### 1. Individual Samples Plot (NEW)
**Module:** `modules/local/plot_peak_intersect_samples.nf`
- **When:** After MACS2_CALLPEAK_SINGLE, before consensus analysis
- **Input:** All individual sample peaks grouped by antibody (6-8 files)
- **Output:** `{antibody}.samples.intersect.plot.pdf`
- **Purpose:** Shows peak overlaps between ALL individual samples

### 2. Condition Consensus Plot (EXISTING)
**Module:** `modules/local/macs2_consensus.nf`
- **When:** After merging condition consensus peaks by antibody
- **Input:** Condition-level consensus peaks (2-3 files)
- **Output:** `{antibody}.boolean.intersect.plot.pdf`
- **Purpose:** Shows peak overlaps between condition consensus

## Implementation

### New Module: PLOT_PEAK_INTERSECT_SAMPLES
```groovy
process PLOT_PEAK_INTERSECT_SAMPLES {
    // Groups all individual sample peaks by antibody
    // Creates boolean matrix and UpSet plot
    // Outputs: intersect.txt and samples.intersect.plot.pdf
}
```

### Workflow Changes
```groovy
// After individual peak calling and QC (line ~629)
if (!params.skip_peak_qc) {
    ch_macs2_peaks
        .map { meta, peak -> [ meta.antibody, peak ] }
        .groupTuple()
        .set { ch_antibody_individual_peaks }

    PLOT_PEAK_INTERSECT_SAMPLES (
        ch_antibody_individual_peaks
    )
}

// Then continues with two-level consensus...
```

## Result
Now you get **TWO** UpSet plots per antibody:
1. **Individual samples plot:** Shows overlaps between all 6-8 individual samples
2. **Condition consensus plot:** Shows overlaps between 2-3 condition consensus peaks

Both plots are meaningful and have sufficient data dimensions for the UpSet visualization.

## Files Modified
- `chipseq/modules/local/plot_peak_intersect_samples.nf` (NEW)
- `chipseq/workflows/chipseq.nf` (added include and process call)
- `chipseq/modules/local/macs2_consensus.nf` (reverted to original - no try/catch)
