# Bowtie2 Multi-Mapper Implementation Summary

## ✅ Completed Implementation

### Files Modified

1. **`conf/modules.config`** (lines 203-207)
   - Added conditional `-k` parameter logic
   - `-k 1` (default): Report best alignment only
   - `-k 50` (with `keep_multi_map = true`): Report up to 50 alignments

### Implementation Details

```groovy
if (params.aligner == 'bowtie2') {
    process {
        withName: '.*:ALIGN_BOWTIE2:BOWTIE2_ALIGN' {
            // Conditional -k handling based on keep_multi_map flag
            // If keep_multi_map = false (default): -k 1 (report only best alignment - unique mappers)
            // If keep_multi_map = true: -k 50 (report up to 50 alignments - allow multi-mappers)
            ext.args   = params.keep_multi_map ? '--very-sensitive --end-to-end --reorder -k 50' : '--very-sensitive --end-to-end --reorder -k 1'
            ext.args2  = '-F4 -bhS'
        }
    }
}
```

### Behavior Matrix

| `keep_multi_map` | Bowtie2 `-k` | NH Tag Filter | Final Output |
|------------------|--------------|---------------|--------------|
| `false` (default) | 1 | Only NH:i:1 | Best alignment from unique mappers |
| `true` | 50 | All NH values | Up to 50 alignments per read |

### Key Differences from STAR

**Bowtie2 `-k 1`:**
- Reports **best alignment** for a read
- Read may still map to multiple locations (multi-mapper)
- MAPQ score indicates uniqueness (0 = multi-mapper)
- Post-processing NH tag filter removes multi-mappers

**STAR `--outFilterMultimapNmax 1`:**
- **Rejects** reads mapping to multiple locations
- Only accepts reads with exactly 1 valid alignment
- More strict filtering **during** alignment

### Consistency Across Aligners

Both STAR and Bowtie2 now use `--keep_multi_map` flag:
- Post-processing NH tag filtering ensures consistent final output
- STAR: stricter during alignment
- Bowtie2: stricter during post-processing

---

## Documentation Updates

1. **`docs/KEEP_MULTI_MAP_LOGIC.md`**
   - Added comprehensive Bowtie2 section
   - Comparison table STAR vs Bowtie2
   - Example scenarios showing behavioral differences
   - Updated summary tables for both aligners

---

## Testing Recommendations

### Test Case 1: Default Behavior (Unique Mappers Only)
```bash
nextflow run main.nf \
    --aligner bowtie2 \
    --input samplesheet.csv \
    --keep_multi_map false  # Default
```

**Expected:**
- Bowtie2 reports `-k 1` (best alignment)
- Post-processing removes reads with `NH:i > 1`
- Final BAM: only unique mappers

### Test Case 2: Keep Multi-Mappers
```bash
nextflow run main.nf \
    --aligner bowtie2 \
    --input samplesheet.csv \
    --keep_multi_map true
```

**Expected:**
- Bowtie2 reports `-k 50` (up to 50 alignments)
- Post-processing keeps all reads (no NH:i filtering)
- Final BAM: unique mappers + multi-mappers (multiple alignments per read)

### Verification Commands

```bash
# Count unique mappers (NH:i:1)
samtools view -F 0x4 sample.bam | grep "NH:i:1" | wc -l

# Count multi-mappers (NH:i > 1)
samtools view -F 0x4 sample.bam | grep -v "NH:i:1" | wc -l

# Check MAPQ distribution
samtools view -F 0x4 sample.bam | cut -f5 | sort | uniq -c | sort -rn

# NH tag distribution
samtools view -F 0x4 sample.bam | grep -oP "NH:i:\d+" | sort | uniq -c
```

---

## References

- [Bowtie2 Manual - Reporting Modes](http://bowtie-bio.sourceforge.net/bowtie2/manual.shtml#reporting-modes)
- [SAM Format Specification - NH Tag](https://samtools.github.io/hts-specs/SAMv1.pdf)
- Pipeline documentation: `docs/KEEP_MULTI_MAP_LOGIC.md`

---

**Implementation Date:** 2025-01-XX  
**Status:** ✅ Complete  
**Tested:** ⏳ Pending
