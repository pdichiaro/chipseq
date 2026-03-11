# Bowtie2 Aligner - Usage Examples

## Overview
This pipeline now supports both STAR and Bowtie2 aligners for ChIP-seq analysis. Choose the aligner that best fits your research needs.

## Quick Start

### Using Bowtie2 with Pre-built Index
```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --outdir results \
    --genome GRCh38 \
    --aligner bowtie2 \
    --bowtie2_index /path/to/bowtie2/index/genome
```

### Using Bowtie2 with Compressed Index
```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --outdir results \
    --aligner bowtie2 \
    --bowtie2_index /path/to/bowtie2_index.tar.gz \
    --fasta /path/to/genome.fa
```

### Building Bowtie2 Index On-the-Fly
```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --outdir results \
    --aligner bowtie2 \
    --fasta /path/to/genome.fa \
    --gtf /path/to/genes.gtf
```

## Comparison: STAR vs Bowtie2

### When to Use STAR
- **Spliced alignment**: RNA-seq or analysis requiring splice junction detection
- **Gene expression**: Transcriptome-based analysis
- **Speed with large datasets**: STAR is optimized for high-throughput data
- **Standard ChIP-seq pipelines**: Default choice for most workflows

### When to Use Bowtie2
- **DNA alignment**: Pure genomic alignment without splice awareness
- **Memory constraints**: Lower memory footprint than STAR
- **Small to medium datasets**: Excellent for focused experiments
- **Compatibility**: Well-established tool with extensive documentation
- **Large genomes**: CSI indexing supports chromosomes >512 Mbp

## Configuration Options

### Basic Parameters
```bash
--aligner bowtie2              # Select Bowtie2 aligner
--bowtie2_index <path>         # Path to Bowtie2 index (directory or .tar.gz)
--fasta <path>                 # Reference genome (required if building index)
```

### Advanced Bowtie2 Configuration
Create a custom config file (`custom.config`):

```groovy
process {
    withName: 'BOWTIE2_ALIGN' {
        ext.args = '--very-sensitive --no-unal'  // Customize alignment parameters
        memory = 16.GB
        cpus = 8
    }
}
```

Run with custom config:
```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --aligner bowtie2 \
    -c custom.config
```

## Index Preparation

### Option 1: Use Pre-built Index from iGenomes
```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --genome GRCh38 \
    --aligner bowtie2
```
*Requires Bowtie2 index in iGenomes configuration*

### Option 2: Build Index Locally (Recommended for Custom Genomes)
```bash
# 1. Build index separately
bowtie2-build genome.fa genome_index

# 2. Use in pipeline
nextflow run main.nf \
    --input samplesheet.csv \
    --aligner bowtie2 \
    --bowtie2_index ./genome_index
```

### Option 3: Let Pipeline Build Index
```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --aligner bowtie2 \
    --fasta genome.fa \
    --gtf genes.gtf
```
*Index will be built automatically and saved to results*

## Example Workflows

### Minimal Example (Small Dataset)
```bash
nextflow run main.nf \
    --input samples.csv \
    --outdir bowtie2_results \
    --aligner bowtie2 \
    --fasta genome.fa \
    --gtf genes.gtf \
    --blacklist blacklist.bed
```

### Production Example (Large Dataset)
```bash
nextflow run main.nf \
    --input chip_samples.csv \
    --outdir production_results \
    --aligner bowtie2 \
    --bowtie2_index /data/indices/bowtie2/hg38 \
    --fasta /data/genomes/hg38.fa \
    --gtf /data/annotations/hg38.gtf \
    --blacklist /data/blacklists/hg38-blacklist.v2.bed \
    --save_reference \
    --save_align_intermeds \
    -profile docker
```

### AWS Batch Example
```bash
nextflow run main.nf \
    --input s3://bucket/samplesheet.csv \
    --outdir s3://bucket/results \
    --aligner bowtie2 \
    --genome GRCh38 \
    -profile awsbatch \
    -w s3://bucket/work
```

## Output Differences

### Alignment Statistics
- **STAR**: Provides detailed `Log.final.out` with splice junction stats
- **Bowtie2**: Provides alignment summary in MultiQC report

### Log Files
Both aligners produce:
- Sorted BAM files with CSI/BAI indices
- Samtools stats, flagstat, and idxstats
- Integration into MultiQC report

### Downstream Compatibility
All downstream steps (filtering, peak calling, QC) are **identical** regardless of aligner choice.

## Troubleshooting

### Issue: Index Not Found
```
ERROR: Bowtie2 index not found at /path/to/index
```
**Solution**: Ensure the index path points to the directory containing `.bt2` files, not the files themselves.

### Issue: Memory Errors
```
ERROR: Process BOWTIE2_BUILD failed
```
**Solution**: Increase memory allocation:
```bash
nextflow run main.nf ... -process.memory 32.GB
```

### Issue: Version Conflicts
```
ERROR: Bowtie2 version mismatch
```
**Solution**: Use containerized execution:
```bash
nextflow run main.nf ... -profile docker
```

## Performance Tips

1. **Pre-build indices**: Building indices is time-consuming; do it once and reuse
2. **Use containers**: Ensure consistent tool versions with `-profile docker` or `singularity`
3. **Adjust threads**: Bowtie2 scales well; use `--max_cpus` to utilize available cores
4. **Large genomes**: Bowtie2's CSI indexing handles large chromosomes efficiently

## Further Reading

- [Bowtie2 Documentation](http://bowtie-bio.sourceforge.net/bowtie2/index.shtml)
- [nf-core ChIP-seq Pipeline](https://nf-co.re/chipseq)
- [Nextflow Documentation](https://www.nextflow.io/docs/latest/index.html)

## Support

For issues specific to Bowtie2 integration, please open an issue on the GitHub repository with:
- Command used
- Error message
- Nextflow version (`nextflow -version`)
- Bowtie2 version (if available)
