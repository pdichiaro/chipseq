# PublishDir Standardization - ChipSeq Pipeline

## Date: 2026-02-23

## Changes Applied

### 1. Moved DESeq2 outputs to mergedLibrary structure

**Modules affected:**
- `NORMALIZE_DESEQ2_QC_ALL_GENES`
- `NORMALIZE_DESEQ2_QC_INVARIANT_GENES`

**Before:**
```
${params.outdir}/
└── deseq2/
    ├── all_genes/
    └── invariant_genes/
```

**After:**
```
${params.outdir}/
└── ${params.aligner}/
    └── mergedLibrary/
        └── deseq2/
            ├── all_genes/
            └── invariant_genes/
```

**Rationale:**
- Consistency with other normalization outputs (deeptools)
- Logical grouping: DESeq2 works on merged libraries, not individual ones
- Better organization: all final outputs under `mergedLibrary/`

---

### 2. Renamed em_filt → filtered_bam

**Module affected:**
- `BAM_FILTER`

**Before:**
```
${params.outdir}/${params.aligner}/mergedLibrary/em_filt/
```

**After:**
```
${params.outdir}/${params.aligner}/mergedLibrary/filtered_bam/
```

**Rationale:**
- Clarity: self-explanatory name (standard ChIP-seq filtered BAMs)
- Avoid confusion: "em_filt" incorrectly suggested EM (Expectation-Maximization) algorithm
- Best practice: descriptive names over legacy/ambiguous ones

**What BAM_FILTER actually does:**
- Removes unmapped reads
- Removes duplicates (default)
- Removes blacklist regions
- Filters by insert size (≤ 1000 bp default)
- Removes multimappers (keeps only NH:i:1, default)
- NO EM algorithm involved

---

## Final Directory Structure

```
${params.outdir}/
└── ${params.aligner}/
    ├── library/                      [Individual libraries - optional]
    │   ├── *.Lb.sorted.bam
    │   ├── samtools_stats/
    │   ├── log/
    │   └── unmapped/
    │
    └── mergedLibrary/                [Merged libraries - final outputs]
        ├── Final_BAM/                (Final sorted BAMs)
        ├── filtered_bam/             ✅ RENAMED (was: em_filt)
        ├── big_wig_depth/
        ├── deeptools/
        │   ├── all_genes/
        │   └── invariant_genes/
        ├── deseq2/                   ✅ MOVED to mergedLibrary
        │   ├── all_genes/
        │   └── invariant_genes/
        ├── phantompeakqualtools/
        ├── picard_metrics/
        └── macs2/
            └── [narrowPeak|broadPeak]/consensus/
```

---

## Impact

### User-facing changes:
- ✅ More intuitive output organization
- ✅ Consistent naming across normalization methods
- ✅ Clearer separation between intermediate and final outputs

### Breaking changes:
- ⚠️ Output paths changed for DESeq2 results
- ⚠️ Output path changed for filtered BAM intermediates
- Users with hardcoded paths will need to update scripts

### Files modified:
- `conf/modules.config` (3 publishDir entries)

---

## Testing Recommendations

1. Verify DESeq2 outputs appear in correct location
2. Verify filtered BAMs (if `save_align_intermeds=true`) in new directory
3. Confirm no broken downstream dependencies
4. Update documentation/examples with new paths
