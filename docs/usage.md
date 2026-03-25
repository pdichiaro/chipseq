# pdichiaro/chipseq: Usage

## Quick Start

```bash
nextflow run pdichiaro/chipseq \
    --input samplesheet.csv \
    --outdir results \
    --genome GRCh38 \
    -profile singularity
```

**Required parameters:** `--input`, `--outdir`, `--genome` (or `--fasta`), `-profile`


## Samplesheet Format

CSV file with 7 columns: `sample`, `fastq_1`, `fastq_2`, `replicate`, `antibody`, `control`, `control_replicate`

**Example (Paired-End with controls):**
```csv
sample,fastq_1,fastq_2,replicate,antibody,control,control_replicate
WT_BCATENIN_IP,IP_rep1_R1.fastq.gz,IP_rep1_R2.fastq.gz,1,BCATENIN,WT_INPUT,1
WT_BCATENIN_IP,IP_rep2_R1.fastq.gz,IP_rep2_R2.fastq.gz,2,BCATENIN,WT_INPUT,2
WT_INPUT,input_rep1_R1.fastq.gz,input_rep1_R2.fastq.gz,1,,,
WT_INPUT,input_rep2_R1.fastq.gz,input_rep2_R2.fastq.gz,2,,,
```

### With Input Controls (Single-End)

**Notes:**
- For single-end data, leave `fastq_2` empty
- Without controls: leave `antibody`, `control`, `control_replicate` empty and set `--with_inputs false`
- Technical replicates with same `replicate` number are automatically merged
- Replicate IDs must be consecutive (1, 2, 3, ...)
- Sample names cannot contain spaces


## Parameters

### Required
- `--input` - Samplesheet CSV file
- `--outdir` - Output directory
- `--genome` (or `--fasta` + `--gtf`) - Reference genome

### Key Options
| Parameter | Default | Description |
|-----------|---------|-------------|
| `--with_inputs` | `true` | Use input controls |
| `--aligner` | `star` | Aligner (star only) |
| `--read_length` | `50` | For MACS2 genome size |
| `--fragment_size` | `200` | Fragment size (SE) |
| `--macs_gsize` | Auto | MACS2 genome size |
| `--skip_deeptools_norm` | `false` | Skip DESeq2 norm |
| `--normalization_method` | `invariant_genes` | DESeq2 method |

### Normalization
Two BigWig types are generated:
1. **CPM** (always) - Standard counts per million
2. **DESeq2** (default) - Size factor normalized, better for differential analysis

Set `--skip_deeptools_norm true` to skip DESeq2 normalization.

---

For the complete parameter reference, see `nextflow_schema.json` or run:
```bash
nextflow run main.nf --help
```

