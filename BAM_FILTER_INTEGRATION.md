# BAM Filter Integration - Implementation Summary

## Overview
This document summarizes the integration of the BAM filtering subworkflow into the ChIP-seq pipeline.

## Changes Made

### 1. Module Creation
- **File**: `modules/local/bam_filter.nf`
- **Purpose**: Filters BAM files using standard ChIP-seq approach
- **Filters Applied**:
  - Removes multimappers (NH:i:1 tag filter)
  - Removes unmapped reads (flags 4, 256)
  - Removes duplicates (flag 1024)
  - Excludes blacklist regions (if provided)
  - Filters by fragment size (removes fragments > 2000bp)
  - Keeps only properly paired reads

### 2. Subworkflow Creation
- **File**: `subworkflows/local/bam_filter.nf`
- **Components**:
  - `BAM_FILTER_PROCESS`: Applies filtering
  - `BAM_SORT_SAMTOOLS`: Sorts filtered BAM and creates index
- **Outputs**:
  - Filtered and sorted BAM
  - BAM index (BAI)
  - Statistics (stats, flagstat, idxstats)

### 3. Main Workflow Integration
- **File**: `workflows/chipseq.nf`
- **Integration Point**: After `MARK_DUPLICATES_PICARD`
- **Channels Modified**:
  - Input: `ch_genome_bam` + `ch_genome_bam_index` → combined into `ch_bam_bai`
  - Output: `BAM_FILTER_SUBWF.out.bam` and `BAM_FILTER_SUBWF.out.bai` → `ch_genome_bam_bai`
  
### 4. Downstream Updates
All downstream processes now use `ch_genome_bam_bai` (filtered BAMs) instead of unfiltered BAMs:
- `PICARD_COLLECTMULTIPLEMETRICS`: Quality metrics on filtered BAMs
- `PHANTOMPEAKQUALTOOLS`: Cross-correlation analysis on filtered BAMs
- IP/Control sample preparation: Filtered BAMs for peak calling
- BigWig generation: Coverage tracks from filtered BAMs

### 5. MultiQC Integration
- Added BAM filter statistics to MultiQC report
- Includes: samtools stats, flagstat, and idxstats outputs

## Filtering Rationale

### Why These Filters?
1. **Multimapper Removal (NH:i:1)**: Ensures reads map uniquely to the genome
2. **Unmapped Read Removal**: Cleans up alignment artifacts
3. **Duplicate Removal**: Prevents PCR amplification bias
4. **Blacklist Filtering**: Removes reads from problematic genomic regions
5. **Fragment Size Filter**: Removes anomalously large fragments
6. **Proper Pair Requirement**: Ensures high-quality paired-end alignments

### Expected Impact
- **Read Reduction**: Expect 10-30% read loss (varies by sample quality)
- **Peak Quality**: Improved peak calling specificity
- **False Positive Rate**: Reduced background noise
- **Reproducibility**: Better correlation between replicates

## Testing

### Syntax Validation
```bash
nextflow lint workflows/chipseq.nf
nextflow lint subworkflows/local/bam_filter.nf
nextflow lint modules/local/bam_filter.nf
```

### Unit Test (Recommended)
```bash
# Test with small dataset
nextflow run workflows/chipseq.nf \
    --input samplesheet.csv \
    --genome GRCh38 \
    --outdir test_results \
    -profile docker \
    --max_cpus 2 \
    --max_memory 8.GB
```

### Validation Checks
1. **BAM Record Count**: Compare read counts before/after filtering
2. **MultiQC Report**: Review filtering statistics
3. **Peak Quality**: Verify FRiP scores improve
4. **BigWig Tracks**: Visual inspection in genome browser

## Configuration

### Default Settings
No new parameters required - uses existing pipeline parameters:
- `params.blacklist`: Blacklist regions for filtering
- Uses quality filters hardcoded in `bam_filter.nf` module

### Optional Customization
To modify filtering criteria, edit `modules/local/bam_filter.nf`:
- Line 32: `samtools view` command with filter flags
- Adjust `-f`, `-F` flags for different quality thresholds
- Modify fragment size filter (`\$9 < 2000 && \$9 > -2000`)

## Troubleshooting

### Issue: "Too many reads filtered"
- **Cause**: Overly aggressive filtering or poor quality alignment
- **Solution**: Check alignment quality metrics; adjust filters if needed

### Issue: "No reads remaining after filtering"
- **Cause**: Sample quality issues or incorrect parameters
- **Solution**: Review FASTQC and alignment metrics; verify blacklist BED format

### Issue: "Missing NH:i tag"
- **Cause**: Aligner did not produce NH tag (unique alignment count)
- **Solution**: This pipeline uses STAR/BWA which produce NH tags. If using custom aligner, ensure NH tag is present.

## Future Enhancements

Possible improvements:
1. **Parameterizable Filters**: Make filter thresholds configurable
2. **Filter Reports**: Generate detailed filtering statistics per sample
3. **Alternative Strategies**: Optional filtering modes (strict/lenient)
4. **Quality Metrics**: Add custom filtering quality metrics to MultiQC

## References

- ENCODE ChIP-seq Guidelines: https://www.encodeproject.org/chip-seq/
- SAMtools Documentation: http://www.htslib.org/doc/samtools.html
- nf-core Best Practices: https://nf-co.re/docs/contributing/guidelines

## Version History

- **v1.0** (2025-01-XX): Initial implementation
  - Created bam_filter module and subworkflow
  - Integrated into main chipseq workflow
  - Added MultiQC reporting
