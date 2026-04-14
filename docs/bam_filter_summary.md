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
│  Output: All concordant pairs (0-1000bp)                          │
└───────────────────────────────────────────────────────────────────┘
         │
         ▼
    raw.sam (fragments 0-1000bp)
         │
         ▼
┌───────────────────────────────────────────────────────────────────┐
│  STEP 2: BAM_FILTER (Initial QC)                                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                                                   │
│  2A. samtools view -F 0x004 -F 0x0008 -f 0x001 -q 1              │
│      └─ Remove: unmapped, mate unmapped, MAPQ < 1                │
│                                                                   │
│  2B. samtools fixmate -r                                          │
│      └─ Fix mate information, remove secondary alignments        │
│                                                                   │
│  2C. awk filter by TLEN (fragment size)                           │
│      └─ Keep only fragments ≤ 500bp (params.insert_size)         │
│                                                                   │
│  Output: sample.filter1.bam (0-500bp fragments)                   │
└───────────────────────────────────────────────────────────────────┘
         │
         ▼
    sample.filter1.bam
    ├─ Proper pairs only
    ├─ Fragments 0-500bp
    ├─ MAPQ ≥ 1
    └─ No secondary/supplementary alignments
         │
         ▼
┌───────────────────────────────────────────────────────────────────┐
│  STEP 3: PICARD MARK DUPLICATES                                   │
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
    ├─ All reads from filter1.bam
    ├─ + FLAG 0x0400 on duplicates
    └─ Metrics: sample.mkD.MarkDuplicates.metrics.txt
         │
         ▼
┌───────────────────────────────────────────────────────────────────┐
│  STEP 4: FINAL FILTER (Duplicates + Blacklist + Other)           │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                                                   │
│  4A. CREATE INCLUDE REGIONS (inverse of blacklist)                │
│  ────────────────────────────────────────────────────────────     │
│                                                                   │
│  bedtools complement \                                            │
│    -i blacklist.bed \                                             │
│    -g genome.sizes > include_regions.bed                          │
│                                                                   │
│  Result: BED file with all regions NOT in blacklist               │
│                                                                   │
│  ────────────────────────────────────────────────────────────     │
│                                                                   │
│  4B. APPLY ALL FILTERS TOGETHER IN ONE STEP                       │
│  ────────────────────────────────────────────────────────────     │
│                                                                   │
│  samtools view -b -h \                                            │
│    -F 0x0004          ← Remove unmapped reads                     │
│    -F 0x0008          ← Remove reads with unmapped mate           │
│    -F 0x0100          ← Remove secondary alignments               │
│    -F 0x0800          ← Remove supplementary alignments           │
│    -f 0x0001          ← Keep only paired reads                    │
│    -f 0x0002          ← Keep only proper pairs                    │
│    ${keep_dups_param} ← -F 0x0400 (remove dups) OR nothing        │
│    -q ${mapq}         ← Remove MAPQ < 1 (usually)                 │
│    -L include_regions.bed  ← Keep only NON-blacklist reads        │
│    sample.mkD.bam > sample.filter2.bam                            │
│                                                                   │
│  Where:                                                           │
│  • keep_dups_param = "-F 0x0400" if params.keep_dups=false        │
│                      (DEFAULT: remove duplicates)                 │
│  • keep_dups_param = "" if params.keep_dups=true                  │
│                      (keep duplicates for analysis)               │
│                                                                   │
│  Output: sample.filter2.bam (FINAL, analysis-ready)               │
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

---

## 🔑 Key SAMtools Commands

### STEP 4B: Final Filter Command (Detailed)

```bash
# Step 4A: Create include regions (inverse of blacklist)
bedtools complement \
    -i blacklist.bed \
    -g genome.sizes > include_regions.bed

# Step 4B: Apply ALL filters in one command
samtools view -b -h \
    -F 0x0004          # Remove unmapped reads (flag 4)
    -F 0x0008          # Remove reads with unmapped mate (flag 8)
    -F 0x0100          # Remove secondary alignments (flag 256)
    -F 0x0800          # Remove supplementary alignments (flag 2048)
    -f 0x0001          # Keep only paired reads (flag 1)
    -f 0x0002          # Keep only proper pairs (flag 2)
    -F 0x0400          # Remove duplicates (flag 1024) [if keep_dups=false]
    -q 1               # Remove MAPQ < 1
    -L include_regions.bed  # Keep only reads NOT in blacklist regions
    sample.mkD.bam > sample.filter2.bam
```

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



## ⚙️ Configuration Parameters

| Parameter | Default | Description | Applied in |
|-----------|---------|-------------|-----------|
| `params.insert_size` | 500 | Max fragment size (bp) | STEP 2 (BAM_FILTER) |
| `params.keep_dups` | false | Keep duplicate reads? | STEP 4 (final filter) |
| `params.mapq` | 1 | Min MAPQ threshold | STEP 2 and STEP 4 |
| `params.blacklist` | auto | Blacklist BED file | STEP 4 (final filter) |



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
