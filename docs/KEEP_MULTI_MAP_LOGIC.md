# Multi-Mapper Handling: `-k` Parameter and `--keep_multi_map` Logic

## Overview

This document explains how the pipeline handles multi-mapping reads (reads that align to multiple genomic positions) and the interaction between aligner parameters (STAR or Bowtie2) and the `--keep_multi_map` flag.

## Background: `-k` Parameter

The `-k` parameter is commonly associated with **bowtie2**, where it specifies the maximum number of alignments to report per read:
```bash
bowtie2 -k 1  # Report only 1 alignment per read (unique mappers)
bowtie2 -k 50 # Report up to 50 alignments per read
```

Since this pipeline uses **STAR aligner** (not bowtie2), the equivalent functionality is controlled by these STAR parameters:

| STAR Parameter | Description | Bowtie2 Equivalent |
|----------------|-------------|-------------------|
| `--outFilterMultimapNmax` | Maximum number of loci a read can map to during filtering | `-k` (pre-filter) |
| `--outSAMmultNmax` | Maximum number of alignments to output in SAM/BAM | `-k` (output) |
| `--winAnchorMultimapNmax` | Maximum multi-mapping for window anchoring | (no direct equivalent) |

## Default Configuration

In `nextflow.config`:
```groovy
params {
    // Multi-mapper control
    outfiltermultimapnmax   = 1    // Only accept reads mapping to 1 location
    outsammultnmax          = 1    // Output only 1 alignment per read
    winanchormultimapnmax   = 1    // Strict anchoring (1 position)
    keep_multi_map          = false // Remove multi-mappers in post-processing
}
```

**Default behavior:** Only uniquely mapped reads are kept (standard ChIP-seq practice)

## Conditional Logic Implementation

### How `--keep_multi_map` Works

The `--keep_multi_map` flag controls multi-mapper handling for **both aligners** (STAR and Bowtie2):

---

## STAR Aligner Implementation

#### 1️⃣ **STAR Alignment Level** (`modules/local/star_align.nf`)

```groovy
// Conditional multi-mapper handling based on keep_multi_map flag
def max_multimap = params.keep_multi_map ? 50 : params.outfiltermultimapnmax
def max_sam_multi = params.keep_multi_map ? 50 : params.outsammultnmax
def max_anchor_multi = params.keep_multi_map ? 50 : params.winanchormultimapnmax

def filtermultimapnmax = "--outFilterMultimapNmax ${max_multimap}"
def outsammultinmax = "--outSAMmultNmax ${max_sam_multi}"
def anchormultimapnmax = "--winAnchorMultimapNmax ${max_anchor_multi}"
```

**Logic:**
- If `keep_multi_map = false` (default):
  - `--outFilterMultimapNmax 1` → Only reads mapping to 1 location pass
  - `--outSAMmultNmax 1` → Output 1 alignment per read
  - `--winAnchorMultimapNmax 1` → Strict anchoring

- If `keep_multi_map = true`:
  - `--outFilterMultimapNmax 50` → Accept reads mapping up to 50 locations
  - `--outSAMmultNmax 50` → Can output up to 50 alignments (but STAR chooses 1 randomly with `--outMultimapperOrder Random`)
  - `--winAnchorMultimapNmax 50` → Allow flexible anchoring

#### 2️⃣ **Post-Processing Level** (`modules/local/bam_filter.nf`)

```groovy
if (params.keep_multi_map == false) {
    // Remove multi-mappers using NH tag filter
    samtools view -h ${prefix}.filter1.bam | \\
        grep -E "(NH:i:1\\b|^@)" | \\  // Keep only NH:i:1 (unique mappers)
        samtools view -b > ${prefix}.filter2.bam
} else {
    // Keep all reads (including multi-mappers)
    # No NH:i filtering applied
}
```

**NH tag explanation:**
- `NH:i:1` → Read maps to exactly 1 location (unique mapper)
- `NH:i:2` → Read maps to 2 locations (multi-mapper)
- `NH:i:10` → Read maps to 10 locations (highly repetitive)

---

## Bowtie2 Aligner Implementation

#### 1️⃣ **Bowtie2 Alignment Level** (`conf/modules.config`)

```groovy
if (params.aligner == 'bowtie2') {
    process {
        withName: '.*:ALIGN_BOWTIE2:BOWTIE2_ALIGN' {
            // Conditional -k handling based on keep_multi_map flag
            ext.args = params.keep_multi_map ? 
                '--very-sensitive --end-to-end --reorder -k 50' : 
                '--very-sensitive --end-to-end --reorder -k 1'
        }
    }
}
```

**Logic:**
- If `keep_multi_map = false` (default):
  - `-k 1` → Report only best alignment (unique mapper)
  - Bowtie2 searches for valid alignments but only outputs the best one

- If `keep_multi_map = true`:
  - `-k 50` → Report up to 50 valid alignments per read
  - Bowtie2 outputs multiple alignments with different alignment scores

**Key Differences from STAR:**
- `-k 1` ≠ "only map to 1 location" (unlike STAR's `--outFilterMultimapNmax 1`)
- `-k 1` = "report best alignment, even if read maps to multiple locations"
- Bowtie2 assigns **MAPQ scores** to indicate uniqueness:
  - `MAPQ = 255` or high → Unique mapper
  - `MAPQ = 0` or low → Multi-mapper (alignment score similar to other positions)

#### 2️⃣ **Post-Processing Level**

Same as STAR implementation (`modules/local/bam_filter.nf`):
- Uses NH tag filtering
- Removes multi-mappers when `keep_multi_map = false`

**Note:** Bowtie2 must add NH tags to output BAM files for post-processing to work correctly.

## Usage Examples

### Example 1: Standard ChIP-seq (Default)
```bash
nextflow run main.nf --input samplesheet.csv --keep_multi_map false
```

**Result:**
- STAR only accepts reads mapping to 1 location
- Post-processing removes any reads with `NH:i > 1`
- **Final output:** Only uniquely mapped reads

### Example 2: CUT&RUN or Broad Regions
```bash
nextflow run main.nf --input samplesheet.csv --keep_multi_map true
```

**Result:**
- STAR accepts reads mapping up to 50 locations
- For multi-mappers, STAR randomly selects 1 position (with `--outMultimapperOrder Random`)
- Post-processing keeps all reads (no NH:i filtering)
- **Final output:** Unique mappers + 1 random position per multi-mapper

### Example 3: Custom Override via Config
```groovy
params {
    keep_multi_map = false
    outfiltermultimapnmax = 10  // Allow up to 10 mappings
}
```

**Result:**
- STAR accepts reads mapping up to 10 locations (instead of 1)
- Post-processing still filters to NH:i:1 (removes multi-mappers)
- **This configuration is contradictory** - best to let `keep_multi_map` control everything

## When to Use `--keep_multi_map true`

✅ **Use when:**
- Analyzing **repetitive regions** (e.g., transposable elements, centromeres)
- Working with **CUT&RUN/CUT&Tag** data (chromatin accessibility)
- Studying **broad histone marks** (H3K9me3, H3K27me3) in repetitive regions
- Maximum sensitivity is required

❌ **Do NOT use when:**
- Standard ChIP-seq with **narrow peaks** (transcription factors)
- Peak calling requires **high specificity**
- Analyzing **unique genomic regions**

## Technical Details

### Why 50 as the maximum?

The value `50` is a common threshold in genomics:
- Reads mapping to >50 locations are often:
  - Simple repeats (AAAA...)
  - Low complexity regions
  - Artifact reads
- STAR's default `--outFilterMultimapNmax` is 10
- 50 provides a balance between sensitivity and specificity

### STAR Multi-Mapper Selection

When a read maps to multiple locations and `--outSAMmultNmax 1` is set:
```bash
--outMultimapperOrder Random  # Select 1 position randomly (default in this pipeline)
```

Other options:
- `Old_2.4`: Select best alignment by score (may introduce bias)
- `Random`: Random selection (recommended for ChIP-seq)

## Comparison: STAR vs Bowtie2 Multi-Mapper Handling

### Behavioral Differences

| Aspect | STAR | Bowtie2 |
|--------|------|---------|
| **Default Mode** | Only unique mappers (`-k 1` equivalent) | Best alignment reported (`-k 1`) |
| **Multi-Mapper Detection** | `--outFilterMultimapNmax` filters during alignment | `-k` controls output, not filtering |
| **Output with `-k 1`** | Only reads mapping to 1 location | Best alignment, regardless of multi-mapping |
| **Quality Indicator** | NH tag (number of alignments) | MAPQ score + NH tag |
| **Random Selection** | `--outMultimapperOrder Random` | Not applicable with `-k 1` |

### Example Scenario

**Read X maps to 3 genomic locations:**
- Location A: alignment score = 100
- Location B: alignment score = 98  
- Location C: alignment score = 95

**STAR with `keep_multi_map = false`:**
```
❌ Read X REJECTED (maps to 3 locations, --outFilterMultimapNmax 1)
```

**Bowtie2 with `-k 1`:**
```
✅ Read X ACCEPTED → Reports Location A (best score)
   MAPQ = 0 (low quality due to multi-mapping)
   NH:i:3 (maps to 3 locations)
```

**Post-processing filter (both aligners):**
```
❌ Read X REMOVED (NH:i:3, keep_multi_map = false requires NH:i:1)
```

### Recommendation

For **consistent behavior** across aligners:
- Use `keep_multi_map = false` (default) to enforce unique mappers
- The post-processing NH tag filter ensures the same final output
- STAR is more strict **during** alignment; Bowtie2 relies **more** on post-processing

## Verification

To check if multi-mappers are present in your BAM files:

```bash
# Count unique mappers (NH:i:1)
samtools view -F 0x4 sample.bam | grep "NH:i:1" | wc -l

# Count multi-mappers (NH:i > 1)
samtools view -F 0x4 sample.bam | grep -v "NH:i:1" | wc -l

# Distribution of NH values
samtools view -F 0x4 sample.bam | grep -oP "NH:i:\d+" | sort | uniq -c
```

## Summary Table

### STAR Aligner

| Configuration | STAR outFilterMultimapNmax | STAR outSAMmultNmax | Post-Filter NH:i | Final Output |
|---------------|----------------------------|---------------------|------------------|--------------|
| `keep_multi_map = false` (default) | 1 | 1 | Only NH:i:1 | Unique mappers only |
| `keep_multi_map = true` | 50 | 50 | All NH values | Unique + multi-mappers (1 random position each) |

### Bowtie2 Aligner

| Configuration | Bowtie2 `-k` | Post-Filter NH:i | Final Output |
|---------------|--------------|------------------|--------------|
| `keep_multi_map = false` (default) | 1 | Only NH:i:1 | Unique mappers only (best alignment) |
| `keep_multi_map = true` | 50 | All NH values | Up to 50 alignments per read |

## References

- [STAR Manual](https://github.com/alexdobin/STAR/blob/master/doc/STARmanual.pdf)
- [SAM Format Specification](https://samtools.github.io/hts-specs/SAMv1.pdf)
- [ChIP-seq Guidelines (ENCODE)](https://www.encodeproject.org/chip-seq/transcription_factor/)

---

**Last Updated:** 2025-03-11  
**Pipeline Version:** 1.0.0  
**Maintainer:** @pdichiaro
