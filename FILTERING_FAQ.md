# Filtering Log - Frequently Asked Questions (FAQ)

## General Questions

### Q1: Why do the percentages add up to more than 100%?

**A**: The filtering categories are **not mutually exclusive**. A single read can belong to multiple categories.

**Example**:
- A read is a PCR duplicate (counted in "Duplicates")
- The same read overlaps a blacklist region (counted in "Blacklist")
- This read is counted in BOTH categories but removed only ONCE

This is why we show both individual categories AND the total:

```
Reads overlapping blacklist regions:       1,500,000  (15.00%)
Duplicate reads (marked by Picard):        3,000,000  (30.00%)
Reads removed by other filters*:           1,575,000  (15.75%)
                                                      --------
Sum of categories:                         6,075,000  (60.75%)  ← May be > total if overlap
Total reads REMOVED (all filters):         6,075,000  (60.75%)  ← Actual unique reads removed
```

In this example, there's no overlap, but if there were, the sum would exceed the total.

---

### Q2: What's the difference between "Reads in blacklist" and "Reads removed by blacklist"?

**A**: There's a subtle but important difference:

- **Reads in blacklist** (what we count): Reads that **overlap** blacklist regions in the input BAM
- **Reads removed by blacklist filter**: May be slightly different if some of those reads were ALSO removed by other filters first

The filtering is done in one step by `samtools view` with multiple flags:
```bash
samtools view -F 0x0004 -F 0x0008 -f 0x0002 -F 0x0400 \
    -q 1 -F 0x0100 -F 0x0800 -L include_regions.bed
```

So a read that is BOTH a duplicate AND in blacklist is only removed once.

---

### Q3: Why is my retention rate so low (~30-40%)?

**A**: Low retention can have several causes:

1. **High PCR duplication** (>50%):
   - Library over-amplified
   - Low library complexity
   - Over-sequencing
   - **Solution**: Reduce PCR cycles, increase input DNA, use UMIs

2. **High blacklist overlap** (>20%):
   - Wrong blacklist file (check genome assembly!)
   - Antibody targeting repetitive regions
   - Non-specific binding
   - **Solution**: Verify blacklist file, check antibody specificity

3. **Poor sequencing quality**:
   - Many multi-mappers (MAPQ < 1)
   - Contamination
   - **Solution**: Check FastQC reports, run fastq_screen

4. **Inappropriate filtering parameters**:
   - Fragment size threshold too strict
   - MAPQ threshold too high
   - **Solution**: Adjust parameters in `modules/local/bam_filter.nf`

---

### Q4: Is 60% retention good or bad?

**A**: **It depends on your experiment!**

| Retention | ChIP-seq TF | ChIP-seq Histone | ATAC-seq | RNA-seq |
|-----------|-------------|------------------|----------|---------|
| >70% | Excellent | Excellent | Excellent | Excellent |
| 60-70% | Good | Good | Good | Good |
| 50-60% | Acceptable | Acceptable | Acceptable | Acceptable |
| 40-50% | Concerning | Concerning | Concerning | Concerning |
| <40% | Poor | Poor | Poor | Poor |

**General rule**: 
- **>60% is typically good**
- **<50% warrants investigation**
- **<30% likely indicates problems**

---

## Technical Questions

### Q5: Which BAM file is the "before" and which is "after"?

**A**:

| BAM File | Stage | Duplicates | Blacklist | Other Filters |
|----------|-------|------------|-----------|---------------|
| **BEFORE** | `sample.mLb.mkD.bam` | Marked (flag 0x0400) | Present | Present |
| **AFTER** | `sample.mLb.mkD.filter2.bam` | Removed | Removed | Removed |

The "BEFORE" BAM is the output of `MARK_DUPLICATES_PICARD`:
- Duplicates are **marked** with flag 0x0400 but **still present**
- All reads (including blacklist) are still there
- No quality filtering applied yet

The "AFTER" BAM is the output of `BAM_FILTER`:
- Duplicates **removed** (`-F 0x0400`)
- Blacklist regions **removed** (via `-L include_regions.bed`)
- Quality filters **applied** (MAPQ, fragment size, etc.)

---

### Q6: How do you calculate "Reads in blacklist"?

**A**: We use `samtools view -c -L <blacklist.bed>` on the BEFORE BAM:

```bash
# Count reads overlapping blacklist regions
samtools view -c -L hg38.blacklist.bed sample.mLb.mkD.bam
```

The `-L` flag includes only reads that overlap the regions in the BED file.

**Important**: This counts ALL reads in blacklist, including:
- Duplicates in blacklist
- Low MAPQ reads in blacklist
- etc.

So there's overlap with other categories!

---

### Q7: How does blacklist filtering actually work?

**A**: It's a bit counterintuitive:

1. The blacklist file contains **bad regions** (e.g., `chr1:1000-2000`)
2. We create an **inverse** BED file (include_regions.bed) with **good regions**
3. We use `samtools view -L include_regions.bed` to keep only reads in **good regions**

```bash
# In prepare_genome.nf, we create the inverse:
grep -v '^#' blacklist.bed | \
    awk 'BEGIN {OFS="\t"} {print $1, 0, $2}' | \
    bedtools complement -i stdin -g genome.fa.fai > include_regions.bed
```

So `-L include_regions.bed` keeps reads OUTSIDE the blacklist!

---

### Q8: Can I change the filtering thresholds?

**A**: Yes! Edit `modules/local/bam_filter.nf`:

```groovy
// Current defaults:
def keep_dups = params.keep_dups ?: false          // Remove duplicates
def keep_multi_map = params.keep_multi_map ?: false // Remove MAPQ < 1
def max_fragment_length = 500                       // Remove fragments > 500bp

// To change fragment size threshold:
awk -F '\\t' 'function abs(x){return ((x < 0.0) ? -x : x)} {if (\$9 > 0 && \$9 <= 500) print}' | \\

// Change 500 to your desired threshold (e.g., 1000)
awk -F '\\t' 'function abs(x){return ((x < 0.0) ? -x : x)} {if (\$9 > 0 && \$9 <= 1000) print}' | \\
```

**Warning**: Changing thresholds affects all samples in your run!

---

### Q9: Why are there so many "other filters"?

**A**: "Other filters" is an umbrella term for:

1. **Multi-mappers** (MAPQ < 1): 
   ```bash
   samtools view -q 1  # Keep only MAPQ >= 1
   ```

2. **Large fragments** (>500bp default):
   ```bash
   awk '{if ($9 > 0 && $9 <= 500) print}'
   ```

3. **Secondary alignments** (flag 0x0100):
   ```bash
   samtools view -F 0x0100
   ```

4. **Supplementary alignments** (flag 0x0800):
   ```bash
   samtools view -F 0x0800
   ```

5. **Unmapped reads** (flags 0x0004, 0x0008):
   ```bash
   samtools view -F 0x0004 -F 0x0008
   ```

To diagnose which filter is removing most reads:
```bash
# Count multi-mappers (MAPQ < 1)
samtools view -c -q 0 sample.bam
samtools view -c -q 1 sample.bam
# Difference = multi-mappers

# Count large fragments
samtools view -f 0x0002 sample.bam | \
    awk '{if ($9 > 500) print}' | wc -l
```

---

## Interpretation Questions

### Q10: My blacklist overlap is 0%. Is that normal?

**A**: **No, that's unusual!** Possible explanations:

1. **Blacklist file is empty or wrong format**:
   ```bash
   wc -l blacklist.bed  # Should be > 0
   head blacklist.bed   # Check format
   ```

2. **Blacklist doesn't match genome assembly**:
   ```bash
   # Check chromosomes in blacklist
   cut -f1 blacklist.bed | sort | uniq
   
   # Compare to chromosomes in BAM
   samtools view -H sample.bam | grep @SQ | cut -f2
   ```

3. **Blacklist filtering was skipped**:
   ```bash
   # Check if parameter was set
   grep "blacklist" .nextflow.log
   ```

**Expected**: Most datasets have 1-20% blacklist overlap.

---

### Q11: Can duplicates and blacklist overlap? How is that handled?

**A**: **Yes, they can overlap!** Example:

```
Read ID: READ001
- Is a PCR duplicate (flag 0x0400)
- Aligns to chr1:1000-1100 (a blacklist region)
```

This read is counted in BOTH categories but only removed ONCE.

**The filtering command removes it once**:
```bash
samtools view \
    -F 0x0400      # Remove duplicates (removes READ001)
    -L include.bed # Remove blacklist (would also remove READ001, but already gone)
```

This is why:
```
Duplicates:         30%
Blacklist:          15%
Sum:               45%  ← If no overlap
Actual removed:    40%  ← If 5% overlap between categories
```

---

### Q12: How do I know if my thresholds are appropriate?

**A**: Compare to similar experiments:

1. **Check published ChIP-seq datasets**:
   - ENCODE portal: https://www.encodeproject.org/
   - Look for similar antibody/cell type
   - Compare retention rates

2. **Check MultiQC report** (if available):
   ```bash
   multiqc results/ -o multiqc_report/
   firefox multiqc_report/multiqc_report.html
   ```

3. **Use nf-core recommended defaults**:
   - MAPQ >= 1 (removes multi-mappers)
   - Fragment size <= 500bp (removes outliers)
   - Remove duplicates (standard practice)

4. **Biological validation**:
   - Do peaks make biological sense?
   - Are known binding sites detected?
   - Compare to other replicates

---

### Q13: What if I want to keep duplicates for some analysis?

**A**: You have two options:

**Option 1**: Use the pre-filtered BAM (BEFORE):
```bash
# This has duplicates marked but present
results/bowtie2/mergedLibrary/sample.mLb.mkD.bam
```

**Option 2**: Change the `keep_dups` parameter:
```bash
# In nextflow.config or command line:
nextflow run main.nf \
    --input samplesheet.csv \
    --keep_dups true  # ← Keep duplicates
```

This will modify the filtering in `BAM_FILTER` to NOT remove duplicates.

---

### Q14: The log says 60% removed, but I only see 40% duplicates + 15% blacklist = 55%. Where's the other 5%?

**A**: Great question! That 5% could be:

1. **Overlap between categories**:
   - Reads that are BOTH duplicates AND in blacklist
   - Counted in both categories but only removed once

2. **"Other filters" category**:
   - Check the log - there should be a third line:
   ```
   Reads removed by other filters*:  500,000  (5.00%)
   ```

3. **Rounding errors**:
   - Percentages are rounded to 2 decimal places
   - Small discrepancies (<0.5%) are normal

To investigate:
```bash
# Manual calculation
BEFORE=$(samtools view -c sample.mLb.mkD.bam)
AFTER=$(samtools view -c sample.mLb.mkD.filter2.bam)
REMOVED=$((BEFORE - AFTER))
echo "Removed: $REMOVED out of $BEFORE = $(($REMOVED * 100 / $BEFORE))%"
```

---

## Troubleshooting Questions

### Q15: The filtering log wasn't generated. What happened?

**A**: Check these common issues:

1. **BLACKLIST_LOG process failed**:
   ```bash
   grep "BLACKLIST_LOG" .nextflow.log
   cat work/<hash>/BLACKLIST_LOG/.command.err
   ```

2. **Missing input files**:
   ```bash
   ls results/bowtie2/mergedLibrary/*.mLb.mkD.bam        # Before BAM
   ls results/bowtie2/mergedLibrary/*.mLb.mkD.filter2.bam # After BAM
   ls genome/*.blacklist.bed                              # Blacklist
   ```

3. **Process was skipped**:
   ```bash
   # Check if blacklist parameter was provided
   grep "blacklist" params.yml
   ```

4. **Output directory doesn't exist**:
   ```bash
   mkdir -p results/bowtie2/mergedLibrary/filtering_metrics
   ```

---

### Q16: Can I run the log generation manually?

**A**: Yes! Here's a standalone script:

```bash
#!/bin/bash

# Set your file paths
BEFORE_BAM="sample.mLb.mkD.bam"
AFTER_BAM="sample.mLb.mkD.filter2.bam"
BLACKLIST_BED="hg38.blacklist.bed"
OUTPUT_LOG="sample.filtering.log"

# Count reads
READS_BEFORE=$(samtools view -c $BEFORE_BAM)
READS_AFTER=$(samtools view -c $AFTER_BAM)
READS_IN_BLACKLIST=$(samtools view -c -L $BLACKLIST_BED $BEFORE_BAM)
DUPLICATES_MARKED=$(samtools view -c -f 0x0400 $BEFORE_BAM)

# Calculate totals
TOTAL_REMOVED=$((READS_BEFORE - READS_AFTER))
OTHER_FILTERS=$((TOTAL_REMOVED - DUPLICATES_MARKED - READS_IN_BLACKLIST))

# Calculate percentages
PERCENT_BLACKLIST=$(awk "BEGIN {printf \"%.2f\", ($READS_IN_BLACKLIST / $READS_BEFORE) * 100}")
PERCENT_DUPLICATES=$(awk "BEGIN {printf \"%.2f\", ($DUPLICATES_MARKED / $READS_BEFORE) * 100}")
PERCENT_OTHER=$(awk "BEGIN {printf \"%.2f\", ($OTHER_FILTERS / $READS_BEFORE) * 100}")
PERCENT_TOTAL=$(awk "BEGIN {printf \"%.2f\", ($TOTAL_REMOVED / $READS_BEFORE) * 100}")
PERCENT_RETAINED=$(awk "BEGIN {printf \"%.2f\", ($READS_AFTER / $READS_BEFORE) * 100}")

# Generate log
cat > $OUTPUT_LOG <<EOF
========================================================================
BAM FILTERING LOG
========================================================================

Total reads (input):                      $(printf "%'d" $READS_BEFORE)

Reads overlapping blacklist regions:      $(printf "%'d" $READS_IN_BLACKLIST)  (${PERCENT_BLACKLIST}%)
Duplicate reads (marked by Picard):       $(printf "%'d" $DUPLICATES_MARKED)  (${PERCENT_DUPLICATES}%)
Reads removed by other filters*:          $(printf "%'d" $OTHER_FILTERS)  (${PERCENT_OTHER}%)

Total reads REMOVED (all filters):        $(printf "%'d" $TOTAL_REMOVED)  (${PERCENT_TOTAL}%)
Total reads RETAINED:                     $(printf "%'d" $READS_AFTER)  (${PERCENT_RETAINED}%)

========================================================================
EOF

echo "Log saved to: $OUTPUT_LOG"
```

---

## Advanced Questions

### Q17: How can I visualize which reads are in each category?

**A**: Use Samtools and BEDtools:

```bash
# Extract duplicates
samtools view -f 0x0400 -b sample.mLb.mkD.bam > duplicates.bam

# Extract reads in blacklist
samtools view -L blacklist.bed -b sample.mLb.mkD.bam > in_blacklist.bam

# Extract multi-mappers (MAPQ < 1)
samtools view -q 0 -b sample.mLb.mkD.bam | \
    samtools view -q 1 -U multi_mappers.bam -b -o /dev/null -

# Visualize in IGV
# Load all BAMs and compare regions
```

---

### Q18: Can I get per-chromosome blacklist statistics?

**A**: Yes! Modify the script:

```bash
# Per-chromosome blacklist overlap
for CHR in chr1 chr2 chr3; do
    COUNT=$(samtools view -c -L <(grep "^${CHR}" blacklist.bed) sample.mLb.mkD.bam)
    echo "$CHR: $COUNT reads in blacklist"
done

# Or use bedtools intersect for more detail
bedtools intersect -a sample.mLb.mkD.bam -b blacklist.bed -c > per_read_blacklist_count.txt
```

---

### Q19: What's the performance impact of these filtering steps?

**A**: Filtering is generally fast:

| Step | Time (10M reads) | Memory |
|------|------------------|--------|
| MARK_DUPLICATES | ~5-10 min | ~2-4 GB |
| BAM_FILTER (samtools) | ~2-5 min | ~500 MB |
| BLACKLIST_LOG | ~1-2 min | ~200 MB |

**Total**: ~10-20 minutes per sample

**Optimization tips**:
- Use `-@ threads` with samtools for parallelization
- Process multiple samples in parallel (Nextflow handles this)

---

### Q20: How do I cite these filtering methods?

**A**: 

- **Picard MarkDuplicates**: http://broadinstitute.github.io/picard/
- **Samtools**: Li H. et al. (2009) The Sequence Alignment/Map format and SAMtools. Bioinformatics, 25, 2078-9. [PMID: 19505943]
- **ENCODE Blacklist**: Amemiya HM. et al. (2019) The ENCODE Blacklist: Identification of Problematic Regions of the Genome. Scientific Reports, 9, 9354. [PMID: 31249361]
- **nf-core/chipseq**: Ewels PA. et al. (2020) The nf-core framework for community-curated bioinformatics pipelines. Nature Biotechnology, 38, 276-278. [PMID: 32055031]

---

## Still Have Questions?

- Check the nf-core/chipseq documentation: https://nf-co.re/chipseq
- Join the nf-core Slack: https://nf-co.re/join/slack
- Open an issue on GitHub: https://github.com/nf-core/chipseq/issues
- Consult ENCODE guidelines: https://www.encodeproject.org/chip-seq/

---

**Remember**: These logs are tools to help you understand your data. Don't panic if numbers look different from expectations - investigate, understand, and make informed decisions about your analysis!
