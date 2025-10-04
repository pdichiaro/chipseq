# BAM Filtering Pipeline Summary

## Complete Filtering Workflow (Bowtie2 → Analysis-Ready BAM)

This document provides a synthetic overview of the complete BAM filtering pipeline used in the ChIP-seq workflow, from raw alignment to the final analysis-ready BAM file.

---

## 📊 Complete Pipeline Flowchart (Paired-End)

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃         COMPLETE FILTERING PIPELINE (PAIRED-END)                  ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

📁 INPUT: sample_R1.fq.gz + sample_R2.fq.gz
         │
         ▼
┌───────────────────────────────────────────────────────────────────┐
│  STEP 1: BOWTIE2 ALIGNMENT                                        │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                                                   │
│  bowtie2 --very-sensitive -X 1000 -x genome                       │
│                                                                   │
│  Output: All concordant pairs (0-1000bp search space)             │
└───────────────────────────────────────────────────────────────────┘
         │
         ▼
    raw.sam (all alignments, 0-1000bp)
         │
         ▼
┌───────────────────────────────────────────────────────────────────┐
│  STEP 2: PICARD MARK DUPLICATES                                   │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                                                   │
│  picard MarkDuplicates \                                          │
│    REMOVE_DUPLICATES=false \  ← Only MARKS, doesn't remove       │
│    ASSUME_SORT_ORDER=coordinate                                   │
│                                                                   │
│  Sets FLAG 0x0400 for duplicate reads                             │
│                                                                   │
│  Output: sample.mkD.bam (duplicates MARKED)                       │
└───────────────────────────────────────────────────────────────────┘
         │
         ▼
    sample.mkD.bam
    ├─ All aligned reads
    ├─ FLAG 0x0400 on duplicates
    └─ Metrics: sample.mkD.MarkDuplicates.metrics.txt
         │
         ▼
┌───────────────────────────────────────────────────────────────────┐
│  STEP 3: BAM_FILTER (2-PASS FILTERING)                            │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ PASS 1: Apply Most Filters                                  │ │
│  │ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │ │
│  │                                                              │ │
│  │ samtools view -b -h \                                        │ │
│  │   -F 0x0100          ← Remove secondary alignments          │ │
│  │   -F 0x0800          ← Remove supplementary alignments      │ │
│  │   -F 0x0004          ← Remove unmapped reads                │ │
│  │   -F 0x0008          ← Remove reads with unmapped mate      │ │
│  │   -f 0x0001          ← Keep only paired reads               │ │
│  │   -f 0x0002          ← Keep only proper pairs               │ │
│  │   -F 0x0400          ← Remove duplicates (if !keep_dups)    │ │
│  │   -L include_regions.bed  ← Keep only NON-blacklist reads   │ │
│  │   sample.mkD.bam > sample.filter1.bam                        │ │
│  │                                                              │ │
│  │ Where include_regions.bed is created by:                     │ │
│  │   bedtools complement -i blacklist.bed -g genome.sizes       │ │
│  │                                                              │ │
│  │ Output: sample.filter1.bam                                   │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│         │                                                         │
│         ▼                                                         │
│    sample.filter1.bam                                             │
│    ├─ Proper pairs only                                           │
│    ├─ No secondary/supplementary alignments                       │
│    ├─ No unmapped reads/mates                                     │
│    ├─ No blacklist regions                                        │
│    └─ No duplicates (if keep_dups=false)                          │
│         │                                                         │
│         ▼                                                         │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ PASS 2: MAPQ + Fragment Size Filtering                      │ │
│  │ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │ │
│  │                                                              │ │
│  │ samtools view -q 1 -h sample.filter1.bam | \                 │ │
│  │   awk -v max="500" \                                         │ │
│  │     '{if($0~/^@/ || (($9>=0?$9:-$9)<=max)) print}' | \       │ │
│  │   samtools view -b > sample.filter2.bam                      │ │
│  │                                                              │ │
│  │ Filters applied:                                             │ │
│  │   • -q 1: Remove MAPQ < 1 (multi-mappers)                    │ │
│  │   • awk: Keep fragments ≤ 500bp (params.insert_size)         │ │
│  │                                                              │ │
│  │ Output: sample.filter2.bam (FINAL)                           │ │
│  └─────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────┘
         │
         ▼
    sample.filter2.bam ✅ FINAL OUTPUT
    ├─ Proper pairs only
    ├─ Fragments 0-500bp
    ├─ MAPQ ≥ 1
    ├─ No secondary/supplementary alignments
    ├─ No duplicates (if params.keep_dups=false)
    └─ No blacklist regions
         │
         ▼
┌───────────────────────────────────────────────────────────────────┐
│  STEP 4: BAM_SORT_SAMTOOLS                                        │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                                                   │
│  samtools sort sample.filter2.bam > sample.filter2.sorted.bam    │
│  samtools index sample.filter2.sorted.bam                         │
│                                                                   │
│  Generates:                                                       │
│  • sample.filter2.sorted.bam (sorted BAM)                         │
│  • sample.filter2.sorted.bam.bai (index)                          │
│  • sample.filter2.sorted.bam.stats (samtools stats)               │
│  • sample.filter2.sorted.bam.flagstat (samtools flagstat)         │
│  • sample.filter2.sorted.bam.idxstats (samtools idxstats)         │
└───────────────────────────────────────────────────────────────────┘
         │
         ▼
┌───────────────────────────────────────────────────────────────────┐
│  STEP 5: GENERATE FILTERING LOG                                   │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                                                   │
│  Creates: sample.filtering.log                                    │
│                                                                   │
│  Counts separately (from sample.mkD.bam):                         │
│  • Total reads: samtools view -c                                  │
│  • Blacklist overlaps: samtools view -c -L blacklist.bed          │
│  • Duplicates: samtools view -c -f 0x0400                         │
│  • Retained reads: samtools view -c sample.filter2.bam            │
│  • Other filters: calculated (total - retained - blacklist - dup) │
│                                                                   │
│  See: FILTERING_LOG_IMPROVEMENTS.md for details                   │
└───────────────────────────────────────────────────────────────────┘
         │
         ▼
    sample.filtering.log
         │
         ▼
    📊 Ready for MACS2 peak calling!
```

---

## 🔑 Key SAMtools Commands

### BAM_FILTER Implementation: 2-Pass Filtering

The BAM_FILTER module uses a **2-pass approach** to efficiently filter BAM files:

```bash
# ────────────────────────────────────────────────────────────────────
# PASS 1: Apply most filters (creates filter1.bam)
# ────────────────────────────────────────────────────────────────────

# First, create include regions (inverse of blacklist)
bedtools complement \
    -i blacklist.bed \
    -g genome.sizes > include_regions.bed

# Then apply all flags-based and blacklist filters
samtools view -b -h \
    -F 0x0100          # Remove secondary alignments (flag 256)
    -F 0x0800          # Remove supplementary alignments (flag 2048)
    -F 0x0004          # Remove unmapped reads (flag 4)
    -F 0x0008          # Remove reads with unmapped mate (flag 8)
    -f 0x0001          # Keep only paired reads (flag 1)
    -f 0x0002          # Keep only proper pairs (flag 2)
    -F 0x0400          # Remove duplicates (flag 1024) [if keep_dups=false]
    -L include_regions.bed  # Keep only reads NOT in blacklist regions
    sample.mkD.bam > sample.filter1.bam

# ────────────────────────────────────────────────────────────────────
# PASS 2: Apply MAPQ + fragment size filters (creates filter2.bam)
# ────────────────────────────────────────────────────────────────────

samtools view -q 1 -h sample.filter1.bam | \
    awk -v max="500" '{if($0~/^@/ || (($9>=0?$9:-$9)<=max)) print}' | \
    samtools view -b > sample.filter2.bam

# Where:
# -q 1: Keep only reads with MAPQ >= 1 (removes multi-mappers)
# awk: Keep only fragments with |TLEN| <= 500bp (params.insert_size)
```

**Why 2 passes instead of 1?**
- **Pass 1** applies all flag-based filters + blacklist filtering in one `samtools view` command
- **Pass 2** adds MAPQ filtering (`-q 1`) + fragment size filtering (via `awk`)
- This separation allows for efficient processing while maintaining clarity

**Why use include regions instead of excluding blacklist?**
- SAMtools `-L` (include) is faster and more reliable than `-U` (exclude)
- `bedtools complement` inverts the blacklist → creates "allowed" regions
- Result: Only reads in allowed regions are kept

---

## 📋 SAM Flags Reference

| Flag | Hex | Meaning | Action in Pipeline |
|------|-----|---------|-------------------|
| **KEEP flags (-f)** |
| 0x0001 | 1 | Read paired | ✅ KEEP paired reads |
| 0x0002 | 2 | Proper pair | ✅ KEEP proper pairs |
| **REMOVE flags (-F)** |
| 0x0004 | 4 | Unmapped | ❌ REMOVE unmapped reads |
| 0x0008 | 8 | Mate unmapped | ❌ REMOVE reads with unmapped mate |
| 0x0100 | 256 | Secondary alignment | ❌ REMOVE secondary alignments |
| 0x0400 | 1024 | PCR/optical duplicate | ❌ REMOVE if keep_dups=false |
| 0x0800 | 2048 | Supplementary alignment | ❌ REMOVE supplementary alignments |

---

## 📊 Filtering Log Categories

The filtering log separates reads into categories:

```
┌─────────────────────────────────────────────────────────────────┐
│ BAM FILTERING LOG - Sample: ENCFF123ABC                         │
│                                                                 │
│ Total reads (input):                      10,000,000           │
│                                                                 │
│ Reads overlapping blacklist regions:       1,500,000 (15.00%) │
│ Duplicate reads (marked by Picard):        3,000,000 (30.00%) │
│ Reads removed by other filters*:           1,575,000 (15.75%) │
│   (*MAPQ < 1, secondary/supplementary alignments)              │
│ ─────────────────────────────────────────────────────           │
│ Total reads REMOVED (all filters):         6,075,000 (60.75%) │
│ Total reads RETAINED:                      3,925,000 (39.25%) │
└─────────────────────────────────────────────────────────────────┘
```

### How Each Category is Counted

| Category | Command | What it counts |
|----------|---------|----------------|
| **Total reads** | `samtools view -c sample.mkD.bam` | All reads in input BAM |
| **Blacklist** | `samtools view -c -L blacklist.bed sample.mkD.bam` | Reads overlapping blacklist regions |
| **Duplicates** | `samtools view -c -f 0x0400 sample.mkD.bam` | Reads marked as duplicates by Picard |
| **Other filters** | Calculated: `(TOTAL - RETAINED) - BLACKLIST - DUPLICATES` | MAPQ < 1, secondary, supplementary |
| **Retained** | `samtools view -c sample.filter2.bam` | Reads in final BAM |

**Important notes:**
- ⚠️ Categories can **overlap** (e.g., a duplicate in a blacklist region)
- ⚠️ Percentages may **sum > 100%** due to overlap
- ✅ "Other filters" is calculated to ensure categories sum exactly to total removed

---

## ⚙️ Configuration Parameters

| Parameter | Default | Description | Applied in |
|-----------|---------|-------------|-----------|
| `params.insert_size` | 500 | Max fragment size (bp) | STEP 2 (BAM_FILTER) |
| `params.keep_dups` | false | Keep duplicate reads? | STEP 4 (final filter) |
| `params.mapq` | 1 | Min MAPQ threshold | STEP 2 and STEP 4 |
| `params.blacklist` | auto | Blacklist BED file | STEP 4 (final filter) |

**How to change:**

```bash
# Keep duplicates for analysis
nextflow run pdichiaro/chipseq --keep_dups true

# More permissive fragment size
nextflow run pdichiaro/chipseq --insert_size 600

# Stricter MAPQ threshold
nextflow run pdichiaro/chipseq --mapq 10

# Custom blacklist
nextflow run pdichiaro/chipseq --blacklist /path/to/custom.bed
```

---

## 📁 File Naming Convention

```
sample.filter1.bam         # After BAM_FILTER (fragment size filter)
sample.mkD.bam             # After MarkDuplicates (duplicates marked)
sample.filter2.bam         # After final filter (analysis-ready)
sample.filtering.log       # Filtering statistics report
```

---

## 📈 Expected Filtering Rates

For typical high-quality ChIP-seq data:

| Filter Category | Expected % | Concern if > |
|----------------|-----------|-------------|
| **Blacklist** | 5-15% | 20% |
| **Duplicates** | 20-40% | 60% |
| **Other filters** | 5-15% | 25% |
| **Total removed** | 30-60% | 75% |
| **Retained** | 40-70% | < 25% |

**Interpreting high removal rates:**

| High Category | Likely Cause | Recommended Action |
|---------------|-------------|-------------------|
| **Blacklist > 20%** | Non-specific antibody, wrong blacklist file | Check antibody specificity; verify genome |
| **Duplicates > 60%** | Over-amplification, low input material | Reduce PCR cycles, increase starting material |
| **Other > 25%** | Quality issues, multi-mappers | Check FastQC reports, verify alignment settings |
| **Retained < 25%** | Multiple issues | Review entire library prep protocol |

---

## 🔍 Single-End vs Paired-End Differences

| Aspect | Paired-End | Single-End |
|--------|-----------|-----------|
| **Fragment size filter** | ✅ Yes (TLEN ≤ 500bp) | ❌ No (no TLEN field) |
| **Mate filters** | ✅ Yes (-F 0x0008, -f 0x0002) | ❌ No mate information |
| **Blacklist filter** | ✅ Yes | ✅ Yes |
| **Duplicate removal** | ✅ Yes | ✅ Yes |
| **MAPQ filter** | ✅ Yes | ✅ Yes |

**Single-End filtering (simplified):**

```bash
# SE: No fragment size or mate filtering
samtools view -b -h \
    -F 0x0004              # Remove unmapped
    -F 0x0100              # Remove secondary
    -F 0x0800              # Remove supplementary
    -F 0x0400              # Remove duplicates (if keep_dups=false)
    -q 1                   # Remove MAPQ < 1
    -L include_regions.bed # Keep only NON-blacklist
    sample.mkD.bam > sample.filter2.bam
```

---

## 🧪 Verification Commands

### Verify each filter step manually:

```bash
# 1. Count total reads
samtools view -c sample.mkD.bam
# Example output: 10,000,000

# 2. Count blacklist overlaps
samtools view -c -L blacklist.bed sample.mkD.bam
# Example output: 1,500,000 (15%)

# 3. Count duplicates
samtools view -c -f 0x0400 sample.mkD.bam
# Example output: 3,000,000 (30%)

# 4. Count retained reads
samtools view -c sample.filter2.bam
# Example output: 3,925,000 (39.25%)

# 5. Verify calculations
# Total removed = Total - Retained
#               = 10,000,000 - 3,925,000 = 6,075,000 (60.75%)
#
# Other filters = Total removed - Blacklist - Duplicates
#               = 6,075,000 - 1,500,000 - 3,000,000 = 1,575,000 (15.75%)
```

### Check for filter overlap:

```bash
# Reads that are BOTH duplicates AND in blacklist
samtools view -c -f 0x0400 -L blacklist.bed sample.mkD.bam
# Example output: 450,000
# These reads contribute to both "Blacklist" and "Duplicates" categories
```

This is why **percentages can sum > 100%** — overlapping categories.

---

## 🎯 Next Steps After Filtering

The final `sample.filter2.bam` is used for:

### 1. Peak Calling (MACS2)
```bash
macs2 callpeak -t sample.filter2.bam -n sample -g hs
```

### 2. BigWig Generation (deepTools)
```bash
bamCoverage -b sample.filter2.bam -o sample.bw --normalizeUsing CPM
```

### 3. Read Coverage Analysis (bedtools)
```bash
bedtools coverage -a peaks.bed -b sample.filter2.bam
```

---

## 📚 Related Documentation

- **[BOWTIE2_AND_BAM_FILTERING.md](BOWTIE2_AND_BAM_FILTERING.md)**: Complete detailed documentation of Bowtie2 alignment and initial BAM filtering
- **[FILTERING_LOG_IMPROVEMENTS.md](FILTERING_LOG_IMPROVEMENTS.md)**: Detailed explanation of the filtering log generation and category calculations

---

**Document Version:** 1.0  
**Last Updated:** 2026-04-14  
**Pipeline:** pdichiaro/chipseq  
**Compatible with:** Nextflow 25.04+, Bowtie2 2.3+, SAMtools 1.9+, Picard 2.27+
