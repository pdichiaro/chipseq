# CWL to Nextflow DSL2 Conversion - ChIP-Seq Pipeline

## Overview
Successfully converted the CWL-based ChIP-Seq pipeline to Nextflow DSL2.

## Key Changes

### 1. Input Handling
- **CWL**: Used YAML samplesheets with separate input/control files
- **Nextflow**: Created unified CSV samplesheet format with columns:
  - `sample`, `fastq_1`, `fastq_2`, `antibody`, `control`, `control_antibody`
  - Sample samplesheet: `assets/test_samplesheet.csv`

### 2. Workflow Structure
- **Main workflow**: `workflows/chipseq.nf`
- **Entry point**: `main.nf`
- **Subworkflows** (in `subworkflows/nf-core/`):
  - `fastq_fastqc_umitools_trimgalore.nf`: QC and trimming
  - `align_star.nf`: STAR alignment with SAMtools processing
  - `bam_markduplicates_picard.nf`: Duplicate marking
  - `bam_stats_samtools.nf`: BAM statistics

### 3. Process Conversions

#### STAR Alignment
- **Module**: `modules/local/star_align.nf`
- **Key parameters**:
  - `outFilterMultimapNmax`
  - `outSAMmultNmax`
  - `winAnchorMultimapNmax`
- **Outputs**: BAM, BAI, log files, transcriptome BAM

#### Genome Preparation
- **Modules created**:
  - `star_genomegenerate.nf`: STAR index generation
  - `gtf2bed.nf`: GTF to BED conversion
  
#### BAM Filtering
- **Module**: `modules/local/bam_filter.nf`
- **Features**:
  - BAMtools filtering
  - Size-based filtering
  - Multi-mapping removal

#### Peak Calling
- **MACS3**: `modules/local/macs3_callpeak.nf`
  - Narrow and broad peaks
  - Auto genome size calculation
- **Homer**: `modules/local/homer_findpeaks.nf`

#### Downstream Analysis
- **Modules**:
  - `plot_homer_annotatepeaks.nf`: Peak annotation plotting
  - `plot_macs_qc.nf`: MACS QC visualization
  - `multiqc.nf`: Comprehensive QC report

### 4. Configuration

#### Base Configuration (`conf/base.config`)
- Process-specific resource requirements
- Label-based configurations
- Error strategies

#### Test Configuration (`conf/test.config`)
- Minimal dataset for pipeline testing
- Parameters:
  - `input`: test samplesheet
  - `fragment_size`: 300
  - `read_length`: 50
  - `macs_gsize`: auto-calculated
  
### 5. Parameter Mapping

| CWL Parameter | Nextflow Parameter | Notes |
|---------------|-------------------|-------|
| `samples` | `input` | CSV samplesheet path |
| `genome_fasta` | `fasta` | Reference genome |
| `genome_gtf` | `gtf` | Gene annotations |
| `star_outFilterMultimapNmax` | `outfiltermultimapnmax` | STAR parameter |
| `star_outSAMmultNmax` | `outsammultnmax` | STAR parameter |
| `star_winAnchorMultimapNmax` | `winanchormultimapnmax` | STAR parameter |
| `fragment_size` | `fragment_size` | Peak calling |
| `read_length` | `read_length` | For genome size calc |

### 6. Output Structure
```
results/
├── pipeline_info/
├── genome/
│   ├── star/
│   ├── gtf2bed/
│   └── blacklist/
├── trimgalore/
├── star/
├── picard/
├── macs3/
├── homer/
└── multiqc/
```

### 7. Testing
Successfully tested with:
```bash
nextflow run . -profile test,docker --outdir results -preview
```

### 8. Known Issues / TODO
- [ ] Optimize resource requirements for production
- [ ] Add support for additional peak callers (if needed)
- [ ] Implement advanced filtering options
- [ ] Add more comprehensive test datasets

## Usage

### Basic Run
```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --fasta genome.fa \
  --gtf genes.gtf \
  --outdir results \
  -profile docker
```

### With Custom Parameters
```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --fasta genome.fa \
  --gtf genes.gtf \
  --fragment_size 200 \
  --read_length 50 \
  --outfiltermultimapnmax 1 \
  --outdir results \
  -profile docker
```

## Samplesheet Format

```csv
sample,fastq_1,fastq_2,antibody,control,control_antibody
SPT6_T0_REP1,/path/to/SPT6_T0_REP1_R1.fastq.gz,/path/to/SPT6_T0_REP1_R2.fastq.gz,SPT6,SPT6_INPUT,
SPT6_INPUT,/path/to/SPT6_INPUT_R1.fastq.gz,/path/to/SPT6_INPUT_R2.fastq.gz,,
```

## Migration Notes

### Differences from CWL Version
1. **Simplified input format**: CSV instead of YAML
2. **Unified parameter system**: All parameters in one place
3. **Better modularity**: Reusable subworkflows and modules
4. **Improved resource management**: Dynamic resource allocation
5. **Enhanced reporting**: Integrated MultiQC with custom config

### Advantages of Nextflow Version
- Native container support (Docker, Singularity, Podman)
- Built-in caching and resume capabilities
- Better scalability (local, HPC, cloud)
- More flexible process definitions
- Easier to extend and maintain

## Contributors
Converted by Seqera AI Assistant

## Date
2025-01-XX
