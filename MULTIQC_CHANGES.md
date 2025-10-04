# MultiQC Configuration Changes - Before & After

## Summary
This document shows the evolution of the `multiqc_config.yml` file during the optimization process.

---

## BEFORE (Original Version)
The original configuration was already optimized and identical to the current version.

## CURRENT (Restored Version)
The file has been restored to its original state and is identical to the version in git.

---

## Key Features of the Configuration

### 1. **DESeq2 Plot Ordering**
Uses numbered prefixes (01., 02., 03., 04., etc.) in plot titles to force alphabetical sorting:
```yaml
custom_content:
  order:
    - '01_featurecounts.deseq2.all_genes.read.distribution_*'
    - '02_featurecounts.deseq2.all_genes.sample.dists_*'
    - '03_featurecounts.deseq2.all_genes.pca*'
    - '04_featurecounts.deseq2.all_genes.pca.top500*'
    - '05_featurecounts.deseq2.invariant_genes.read.distribution_*'
    - '06_featurecounts.deseq2.invariant_genes.sample.dists_*'
    - '07_featurecounts.deseq2.invariant_genes.pca*'
    - '08_featurecounts.deseq2.invariant_genes.pca.top500*'
```

### 2. **Module Organization**
The configuration organizes modules by processing stage:
- **LIB**: Individual library processing (FastQC raw/trimmed, cutadapt)
- **MERGED LIB**: Merged library processing (SAMTools, Picard, Preseq)
- **MERGED LIB (unfiltered/filtered)**: Pre- and post-filtering stages

### 3. **Report Section Ordering**
Uses `before` and `after` directives to create a logical flow of sections:
```yaml
report_section_order:
  # Peak calling and QC metrics chain (using before directives)
  peak_count:
    before: mlib_deeptools
  frip_score:
    before: peak_count
  peak_annotation:
    before: frip_score
  strand_shift_correlation:
    before: peak_annotation
  nsc_coefficient:
    before: strand_shift_correlation
  rsc_coefficient:
    before: nsc_coefficient
  mlib_featurecounts:
    before: rsc_coefficient
  # DESeq2 QC parent section (positioned after featureCounts)
  deseq2-featurecounts-qc:
    after: mlib_featurecounts
  # DESeq2 individual plots (ordered within parent section)
  01_deseq2_read_distribution:
    after: deseq2-featurecounts-qc
  02_deseq2_sample_distance:
    after: 01_deseq2_read_distribution
  # ... (continues for plots 03-08)
  # Summary section (positioned at the end)
  nf-core-chipseq-summary:
    order: 10000
```

### 4. **Performance Optimizations**
File search patterns are optimized for speed:
```yaml
sp:
  cutadapt:
    fn: "*trimming_report.txt"
  preseq:
    fn: "*.lc_extrap.txt"
  deeptools/plotFingerprintOutRawCounts:
    fn: "*plotFingerprint*"
  deeptools/plotProfile:
    fn: "*plotProfile*"
  phantompeakqualtools/out:
    fn: "*.spp.out"
  software_versions:
    fn: "EXCLUDE_THIS_FILE"
```

### 5. **Dynamic DESeq2 Handling**
The configuration leverages dynamic parent section creation:
```yaml
# DESeq2 plots are now handled dynamically by DESEQ2_TRANSFORM module headers
# The module adds parent_id/parent_name for all quantifiers automatically
# Plot ordering within parent sections is controlled by numbered prefixes (01., 02., 03., 04.)
# in section titles to ensure correct alphabetical sorting (plot_order doesn't work in nested sections)
```

---

## Status: ✅ RESTORED
The `multiqc_config.yml` file has been verified and is identical to the original version in the git repository.

**Last Updated**: 2026-03-31
**Verification**: File content matches `git show HEAD:assets/multiqc_config.yml`
