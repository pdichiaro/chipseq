# Consensus Peaks Workflow Modifications - README

## 📋 Quick Overview

This directory contains modifications to the ChIP-seq pipeline that implement a **two-stage hierarchical consensus workflow** for peak merging.

## 🎯 What Changed?

**BEFORE**: Peaks were merged directly by antibody
```
Individual Peaks → Merge by Antibody → Final Consensus
```

**AFTER**: Peaks are merged in two stages
```
Individual Peaks → Merge by Condition → Merge by Antibody → Final Consensus
```

**Key Change**: Files are now organized by antibody, with condition-level consensus in a `by_condition/` subdirectory.

## 📁 Output Structure

```
consensus_peaks/
└── BCATENIN/                    # All BCATENIN files here
    ├── by_condition/            # NEW: Condition-level consensus
    │   ├── WT_BCATENIN.bed
    │   └── NAIVE_BCATENIN.bed
    └── BCATENIN.bed             # Final antibody consensus
```

## 📚 Documentation Files

### Essential Reading (in order):

1. **`CHANGES_SUMMARY.md`** ⭐ START HERE
   - Overview of all commits
   - What was changed and why
   - Testing checklist

2. **`CONSENSUS_WORKFLOW_DIAGRAM.md`**
   - Visual workflow diagram
   - Step-by-step data flow
   - Multiple examples

3. **`EXAMPLE_OUTPUT.md`**
   - Realistic output structure
   - File descriptions
   - QC and analysis examples

4. **`IMPLEMENTATION_SUMMARY.md`**
   - Technical implementation details
   - For developers/advanced users

## 🚀 Quick Start

### For Users

**No changes required!** The pipeline works exactly as before, but now:
- ✅ Condition-level consensus files are available for QC
- ✅ All files for an antibody are in one directory
- ✅ Clear separation of intermediate vs final results

**To use**:
```bash
nextflow run main.nf --input samplesheet.csv --outdir results [other params]
```

**To explore results**:
```bash
# See all BCATENIN files
ls results/consensus_peaks/BCATENIN/

# Check condition-level consensus
ls results/consensus_peaks/BCATENIN/by_condition/

# View final consensus
less results/consensus_peaks/BCATENIN/BCATENIN.bed
```

### For Developers

**Modified files**:
- `modules/local/macs2_consensus_by_condition.nf` (NEW)
- `workflows/chipseq.nf` (MODIFIED)

**Key changes**:
1. New module clones MACS2_CONSENSUS with different publishDir
2. Workflow now runs two consensus steps instead of one
3. Channel logic extracts and preserves antibody metadata

**To review changes**:
```bash
git log --oneline -5
git show 869fb04  # Initial implementation
git show 2e87f9a  # Directory reorganization
```

## 🔍 What Gets Created?

### For Each Condition (e.g., WT_BCATENIN)
Located in: `consensus_peaks/{ANTIBODY}/by_condition/`

- `*.bed` - Peak regions
- `*.saf` - For quantification
- `*.pdf` - Overlap plots
- `*.txt` - Statistics and metadata

### For Each Antibody (e.g., BCATENIN)
Located in: `consensus_peaks/{ANTIBODY}/`

- Same files as above, but merging all conditions

## ✅ Benefits

| Before | After |
|--------|-------|
| Single merge step | Two-stage merge |
| Files scattered | Files grouped by antibody |
| No condition QC | Can QC each condition |
| Black box | Clear traceability |

## 🧪 Testing

After running the pipeline, verify:

```bash
# Check directory structure
tree results/consensus_peaks/

# Verify condition files exist
ls results/consensus_peaks/*/by_condition/*.bed

# Verify final files exist
ls results/consensus_peaks/*/*.bed

# Count peaks at each stage
for f in results/consensus_peaks/BCATENIN/by_condition/*.bed; do
    echo "$(basename $f): $(wc -l < $f) peaks"
done
echo "Final: $(wc -l < results/consensus_peaks/BCATENIN/BCATENIN.bed) peaks"
```

## 🔧 Parameters

**`params.min_reps_consensus`** (default: 1)

Applied at **both** stages:
- Stage 1: Minimum replicates per condition
- Stage 2: Minimum conditions per antibody

Example with 3 conditions:
- `min_reps_consensus = 1`: Keep peaks in ≥1 condition (union)
- `min_reps_consensus = 2`: Keep peaks in ≥2 conditions
- `min_reps_consensus = 3`: Keep peaks in all 3 conditions (intersection)

## 📊 Example Workflow

Real-world example with your data:

```
Sample: WT_BCATENIN_IP_REP1_T1
        WT_BCATENIN_IP_REP2_T1
        WT_BCATENIN_IP_REP3_T1
        NAIVE_BCATENIN_IP_REP1_T1
        NAIVE_BCATENIN_IP_REP2_T1
        NAIVE_BCATENIN_IP_REP3_T1
                ↓
        MACS2_CALLPEAK
                ↓
Individual peaks:
        WT_BCATENIN_IP_REP1_T1_peaks.broadPeak
        WT_BCATENIN_IP_REP2_T1_peaks.broadPeak
        ... (6 files total)
                ↓
      STAGE 1: Group by condition
                ↓
        ┌───────────────────┬───────────────────┐
        ↓                   ↓                   ↓
    WT_BCATENIN       NAIVE_BCATENIN      (other conditions)
    (3 replicates)    (3 replicates)
        ↓                   ↓
MACS2_CONSENSUS_BY_CONDITION
        ↓                   ↓
    WT_BCATENIN.bed   NAIVE_BCATENIN.bed
        ↓                   ↓
        └───────────┬───────┘
                    ↓
          STAGE 2: Merge by antibody
                    ↓
            MACS2_CONSENSUS
                    ↓
              BCATENIN.bed
```

## 🐛 Troubleshooting

### Issue: No `by_condition/` directory created

**Check**:
- Are there multiple replicates per condition?
- Is `params.min_reps_consensus` set appropriately?

### Issue: Final consensus file is empty

**Check**:
- Are condition consensus files populated?
- Is `params.min_reps_consensus` too stringent?
- Review log files for MACS2_CONSENSUS

### Issue: Files in wrong directory

**Verify**:
- Check that antibody metadata is being extracted correctly
- Review workflow log for channel contents

## 📞 Support

If you encounter issues:

1. Check the documentation files (especially CHANGES_SUMMARY.md)
2. Review the example output structure (EXAMPLE_OUTPUT.md)
3. Examine the workflow diagram (CONSENSUS_WORKFLOW_DIAGRAM.md)
4. Check Nextflow logs: `.nextflow.log`

## 🎓 Learn More

- **Nextflow Documentation**: https://www.nextflow.io/docs/latest/
- **nf-core ChIP-seq**: https://nf-co.re/chipseq
- **MACS2 Documentation**: https://github.com/macs3-project/MACS

## 📝 Commits Summary

5 commits implementing the two-stage consensus workflow:

1. `869fb04` - Initial implementation
2. `2e87f9a` - Reorganize output into antibody directories
3. `89f48b2` - Add workflow diagram documentation
4. `56f3633` - Add comprehensive changes summary
5. `dd9e1ce` - Add example output structure

All commits are ready locally. Push when SSL connectivity is restored.

## ✨ Credits

Implemented based on user feedback:
> "dovrebbero essere esportati dentro antibody? perchè cmq sono le condition di ogni antibody"

The hierarchical organization keeps all antibody-related files together while providing clear traceability through the analysis stages.

---

**Happy peak calling! 🧬**
