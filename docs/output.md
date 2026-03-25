# pdichiaro/chipseq: Output

## Key Outputs
### Core Results
- **`filtered/`** - Filtered BAM files (final aligned reads)
- **`macs2/`** - Called peaks (narrowPeak/broadPeak files)
- **`consensus_peaks/`** - Consensus peaks across replicates
- **`homer/`** - Peak annotations (genomic features)
- **`featureCounts/`** - Peak read counts

### BigWig Tracks
- **`bigwig/cpm/`** - CPM-normalized coverage (always generated)
- **`bigwig/deseq2/`** - DESeq2-normalized coverage (default, better for differential analysis)

### QC & Reports
- **`multiqc/multiqc_report.html`** - Combined QC report
- **`fastqc/`** - Read quality
- **`phantompeakqualtools/`** - ChIP-seq quality metrics
- **`deeptools/`** - Fingerprint and profile plots

### DESeq2 Outputs (if enabled)
- **`deseq2/invariant_genes/`** - Normalization files, PCA plots, sample distances

---

## Important Notes

### Peak Files
- **Single peaks**: Per-sample peaks
- **Consensus peaks**: High-confidence peaks across replicates (recommended for analysis)

### BigWig Selection
- **CPM**: Good for browser visualization
- **DESeq2**: Better for differential binding analysis

### Aligner
- Uses **Bowtie2** (not STAR)
- For PE data: Filters fragments >500bp by default (use `--insert_size` to change)

For detailed output structure, see the complete directory tree in the pipeline documentation.
