# pdichiaro/chipseq: Output

## Directory Structure by Normalization Method

This document shows the complete output directory structure for the ChIP-seq pipeline with different normalization methods.

## Common Preprocessing Outputs (all methods)
```
results/
├── fastqc/                           # FastQC quality reports
│   ├── <SAMPLE>_fastqc.html
│   └── <SAMPLE>_fastqc.zip
├── trimgalore/                       # TrimGalore outputs
│   ├── <SAMPLE>_val_*.fq.gz         # Trimmed reads
│   ├── logs/
│   └── fastqc/                       # Post-trim FastQC
├── star/                             # STAR alignment outputs
│   ├── <SAMPLE>.Aligned.sortedByCoord.out.bam
│   ├── <SAMPLE>.Log.final.out
│   └── log/
├── samtools/                         # Samtools statistics
│   ├── stats/
│   ├── flagstat/
│   └── idxstats/
└── genome/                           # Reference files (if --save_reference)
    ├── *.fa
    ├── *.gtf
    └── index/
        └── star/
```

## Merged and Filtered BAMs
```
picard/
├── mergesamfiles/                    # Merged technical replicates
│   └── <SAMPLE_merged>.bam
└── markduplicates/                   # Duplicate marking
    ├── <SAMPLE>.markdup.bam
    ├── <SAMPLE>.markdup.metrics.txt
    └── <SAMPLE>.CollectMultipleMetrics.*

filtered/                             # Final filtered BAMs
├── <SAMPLE>.filtered.bam            # BAM files (duplicates removed, blacklist filtered)
├── <SAMPLE>.filtered.bam.bai        # BAM indices
└── samtools/                         # Filtered BAM statistics
    ├── stats/
    ├── flagstat/
    └── idxstats/
```

## Quality Control Outputs
```
phantompeakqualtools/                 # Strand cross-correlation QC
├── <SAMPLE>.spp.out                 # NSC, RSC metrics
├── <SAMPLE>.spp.rdata
└── <SAMPLE>.spp.pdf                 # Cross-correlation plot

deeptools/
├── plotfingerprint/                  # Sample quality metrics
│   ├── <SAMPLE>.plotFingerprint.pdf
│   └── <SAMPLE>.plotFingerprint.raw.txt
└── plotprofile/                      # Profile plots (if not skipped)
    ├── computeMatrix/
    ├── <SAMPLE>.plotProfile.pdf
    └── <SAMPLE>.plotHeatmap.pdf
```

## Peak Calling and Analysis
```
macs2/
├── single_peaks/                     # Peaks called per sample
│   ├── <SAMPLE>_peaks.narrowPeak    # ENCODE format peaks
│   ├── <SAMPLE>_peaks.xls           # Detailed peak table
│   ├── <SAMPLE>_summits.bed         # Peak summits
│   └── <SAMPLE>_model.r             # MACS2 model script
└── merged_peaks/                     # Peaks called on merged antibody BAMs
    └── <ANTIBODY>_peaks.narrowPeak

consensus_peaks/                      # Consensus peaks per antibody
├── <ANTIBODY>.consensus_peaks.bed   # Final consensus peaks
├── <ANTIBODY>.consensus_peaks.saf   # SAF format for featureCounts
├── <ANTIBODY>.boolean.txt           # Peak presence/absence matrix
└── <ANTIBODY>.intersect.txt         # Peak intersection details

homer/
├── macs2/                            # MACS2 peak annotation
│   └── <SAMPLE>.annotatePeaks.txt
└── consensus/                        # Consensus peak annotation
    └── <ANTIBODY>.annotatePeaks.txt

featureCounts/                        # Peak quantification
├── <ANTIBODY>.featureCounts.txt     # Read counts per peak
└── <ANTIBODY>.featureCounts.txt.summary
```

## BigWig Coverage Tracks
```
bigwig/
├── raw/                              # Depth-normalized BigWigs
│   └── <SAMPLE>.bigWig              # Normalized by sequencing depth
└── normalized/                       # DESeq2-normalized BigWigs
    ├── all_genes/                    # Normalized using all_genes method
    │   └── <SAMPLE>.norm.bw
    └── invariant_genes/              # Normalized using invariant_genes method
        └── <SAMPLE>.norm.bw
```

## Normalization and QC (if --normalize)
```
deseq2/
├── all_genes/                        # Standard DESeq2 normalization
│   ├── <ANTIBODY>.scaling_factors.txt      # Size factors
│   ├── <ANTIBODY>.normalized_counts.txt    # Normalized counts
│   ├── <ANTIBODY>.pca_plot.pdf            # PCA analysis
│   ├── <ANTIBODY>.sample_distances.pdf    # Sample distance heatmap
│   ├── <ANTIBODY>.read_distribution.pdf   # Read distribution
│   └── <ANTIBODY>.size_factors.RData      # R object
└── invariant_genes/                  # Stable genes normalization
    └── [Same structure as all_genes/]
```

## Final Report
```
multiqc/
├── multiqc_report.html              # Interactive QC report
└── multiqc_data/                     # MultiQC data files
    ├── multiqc_fastqc.txt
    ├── multiqc_star.txt
    ├── multiqc_picard_dups.txt
    ├── multiqc_phantompeakqualtools.txt
    └── multiqc_featureCounts.txt

pipeline_info/
├── nf_core_chipseq_software_mqc_versions.yml
├── execution_report.html
├── execution_timeline.html
├── execution_trace.txt
└── pipeline_dag.svg                  # Pipeline DAG (if -with-dag)
```

## Key Notes

### Sample Naming and Merging
- Technical replicates with `_T[0-9]+` suffix are automatically merged
- Example: `SAMPLE1_H3K27ac_T1` and `SAMPLE1_H3K27ac_T2` → merged to `SAMPLE1_H3K27ac`
- Biological replicates (same antibody) are used for consensus peak calling

### Peak Calling Strategy
- **Single peaks**: Called on individual samples (or merged technical replicates)
- **Merged peaks**: Called on all BAMs merged by antibody
- **Consensus peaks**: High-confidence peaks replicated across samples of same antibody

### Normalization Methods
- `all_genes`: Standard DESeq2 median-of-ratios normalization
- `invariant_genes`: Normalization using stable genes only (more robust for ChIP-seq)
- Can run both methods simultaneously with `--normalization_method 'all_genes,invariant_genes'`

### Recommended Files for Downstream Analysis
1. **Peaks**: `consensus_peaks/<ANTIBODY>.consensus_peaks.bed`
2. **Browser tracks**: `bigwig/normalized/<METHOD>/<SAMPLE>.norm.bw`
3. **Annotations**: `homer/consensus/<ANTIBODY>.annotatePeaks.txt`
4. **Quantification**: `featureCounts/<ANTIBODY>.featureCounts.txt`
5. **QC report**: `multiqc/multiqc_report.html`

### Output Variations
- If `--with_inputs false`: Peak calling performed without input controls
- If `--skip_peak_annotation`: HOMER annotation directories not created
- If `--normalize false`: No DESeq2 normalization or normalized BigWigs generated
- If `--skip_plot_profile`: deepTools profile/heatmap outputs not created

