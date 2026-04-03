# Assets Directory

This directory contains example samplesheets and configuration files for the pdichiaro/chipseq pipeline.

## Example Samplesheets

All samplesheets follow the nf-core ChIP-seq standard format with 7 columns:
```
sample,fastq_1,fastq_2,replicate,antibody,control,control_replicate
```

### Available Examples

| File | Description | Use Case |
|------|-------------|----------|
| `samplesheet_example.csv` | Basic paired-end with controls | Standard ChIP-seq with input controls |
| `samplesheet_example_complete.csv` | Multi-condition paired-end | Complex experimental design with multiple conditions and antibodies |
| `samplesheet_example_single_end.csv` | Single-end with controls | Single-end sequencing data |
| `samplesheet_example_no_controls.csv` | Paired-end without controls | ChIP-seq without input controls (requires `--with_inputs false`) |

### Format Requirements

- **sample**: Sample name (alphanumeric, underscores, dots, dashes only)
- **fastq_1**: Path to Read 1 FASTQ file (required)
- **fastq_2**: Path to Read 2 FASTQ file (leave empty for single-end)
- **replicate**: Replicate number (integer: 1, 2, 3, ...)
- **antibody**: Antibody/target name (empty for input samples)
- **control**: Name of the control/input sample
- **control_replicate**: Replicate number of the control sample

For detailed usage instructions, see the [usage documentation](../docs/usage.md).

## Other Files

- `multiqc_config.yml` - MultiQC configuration
- `schema_input.json` - JSON schema for samplesheet validation
- `blacklists/` - Genomic blacklist regions for various genomes
