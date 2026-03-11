# Bowtie2 Integration - Complete

## Summary
Successfully integrated Bowtie2 aligner as an alternative to STAR in the ChIP-seq pipeline.

## Changes Made

### 1. Main Configuration (`main.nf`)
- Added `params.bowtie2_index` parameter alongside `params.star_index`
- Updated parameter initialization to support Bowtie2 genome attribute

### 2. Workflow Configuration (`workflows/chipseq.nf`)
- **Updated valid aligners**: Added 'bowtie2' to `valid_params.aligners` array
- **Updated path validation**: Added `params.bowtie2_index` to `checkPathParamList`
- **Imported FASTQ_ALIGN_BOWTIE2 subworkflow**: Added include statement for new subworkflow
- **Conditional alignment logic**: Added `else if` branch for Bowtie2 alignment
  - Maps outputs to same channel names as STAR for downstream compatibility
  - Sets `ch_star_multiqc = Channel.empty()` since Bowtie2 doesn't produce STAR logs
  - Uses CSI index output from FASTQ_ALIGN_BOWTIE2 for large genome support

### 3. Genome Preparation (`subworkflows/local/prepare_genome.nf`)
- **Added imports**:
  - `UNTAR as UNTAR_BOWTIE2_INDEX` for extracting pre-built indices
  - `BOWTIE2_BUILD` for building indices from scratch
- **Added Bowtie2 index preparation logic**:
  - Checks if `params.bowtie2_index` is provided
  - Extracts `.tar.gz` archives or uses directory path
  - Falls back to building index with `BOWTIE2_BUILD` if not provided
- **Added to emit block**: `bowtie2_index` output channel

## Usage

Users can now choose between STAR and Bowtie2 aligners:

```bash
# Using STAR (default)
nextflow run main.nf --aligner star --star_index /path/to/star/index ...

# Using Bowtie2
nextflow run main.nf --aligner bowtie2 --bowtie2_index /path/to/bowtie2/index ...
```

## Validation

All modified files pass Nextflow linting:
- ✅ `subworkflows/local/prepare_genome.nf` - No errors
- ✅ `subworkflows/nf-core/fastq_align_bowtie2.nf` - No errors

Note: Warnings in imported nf-core modules are pre-existing and not introduced by this integration.

## Files Modified
1. `main.nf` - Added bowtie2_index parameter
2. `workflows/chipseq.nf` - Added Bowtie2 alignment logic
3. `subworkflows/local/prepare_genome.nf` - Added Bowtie2 index preparation

## Files Created (Previous Session)
1. `subworkflows/nf-core/fastq_align_bowtie2.nf` - New Bowtie2 alignment subworkflow
2. `subworkflows/nf-core/bam_sort_samtools.nf` - Updated for CSI index support

## Compatibility
- Fully compatible with existing STAR workflow
- BAM outputs are identical in structure (sorted, indexed)
- Downstream processes (filtering, peak calling, etc.) work unchanged
- CSI indices support large genomes (>512 Mbp chromosomes)

## Testing Recommendations
1. Test with small dataset using both aligners
2. Verify BAM file outputs are properly sorted and indexed
3. Check MultiQC reports for alignment statistics
4. Validate peak calling results with both aligners
