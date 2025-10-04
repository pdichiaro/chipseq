# BAM Filtering Log Improvements - README

## 🎯 What This Is

This directory contains improvements to the **BAM filtering log** in the nf-core/chipseq pipeline. The changes make the filtering statistics **accurate, transparent, and actionable**.

---

## ⚡ Quick Start (2 minutes)

### The Problem (BEFORE):
```
Blacklist Filtering Log
Reads removed: 60.75%
```
❌ **Misleading!** This counted ALL filters (duplicates, MAPQ, fragment size, etc.), not just blacklist.

### The Solution (AFTER):
```
BAM Filtering Log

Reads overlapping blacklist regions:   15.00%
Duplicate reads (marked by Picard):    30.00%
Reads removed by other filters:        15.75%
─────────────────────────────────────────────
Total reads REMOVED:                   60.75%
Total reads RETAINED:                  39.25%
```
✅ **Accurate!** Each filter type is counted separately.

---

## 📂 Files Overview

| File | Purpose | Read Time |
|------|---------|-----------|
| **FILTERING_DOCUMENTATION_INDEX.md** ⭐ | Complete navigation guide | 5 min |
| **SUMMARY_OF_CHANGES.md** ⭐ | Quick overview of changes | 5 min |
| **INTERPRETING_FILTERING_LOGS.md** ⭐ | How to understand your results | 15 min |
| **FILTERING_FAQ.md** | 20+ questions & answers | Browse as needed |
| **FILTERING_LOG_IMPROVEMENTS.md** | Technical deep-dive | 10 min |
| **test_filtering_calculations.sh** | Test/validation script | Run anytime |

⭐ = **Recommended to read first**

---

## 🚀 I Want To...

### "Understand what changed"
→ Read: **SUMMARY_OF_CHANGES.md**

### "Interpret my filtering results"
→ Read: **INTERPRETING_FILTERING_LOGS.md**
- Section: "Understanding the Numbers"
- Check: "Quick Reference Table"

### "My retention rate is low, what do I do?"
→ Read: **INTERPRETING_FILTERING_LOGS.md**
- Find your scenario (high duplicates? high blacklist?)
- Follow the troubleshooting workflow

### "Answer a specific question"
→ Read: **FILTERING_FAQ.md**
- 20+ common questions with detailed answers
- Covers technical, interpretation, and troubleshooting topics

### "Understand the technical details"
→ Read: **FILTERING_LOG_IMPROVEMENTS.md**
- Explains WHY the changes were needed
- Shows BEFORE/AFTER comparison
- Details the filtering logic

### "Verify the calculations are correct"
→ Run: **test_filtering_calculations.sh**
```bash
chmod +x test_filtering_calculations.sh
./test_filtering_calculations.sh
```

---

## 📊 Quick Reference

### Is My Retention Rate Good?

| Retention % | Status | Action |
|-------------|--------|--------|
| **>70%** | ✅ Excellent | No action needed |
| **60-70%** | ✅ Good | No action needed |
| **50-60%** | ⚠️ Acceptable | Monitor, compare to similar experiments |
| **40-50%** | ⚠️ Concerning | Investigate which filter is high |
| **<40%** | ❌ Poor | Action required - see troubleshooting |

### Common Issues:

| High Value | Likely Cause | Where to Read |
|------------|--------------|---------------|
| **Blacklist >20%** | Wrong file, non-specific antibody | INTERPRETING - Scenario 3; FAQ Q10 |
| **Duplicates >50%** | Over-amplification, low complexity | INTERPRETING - Scenario 2; FAQ Q3 |
| **Other filters >30%** | Quality issues, multi-mappers | INTERPRETING - Scenario 4; FAQ Q9 |

---

## 🎓 Learning Path

### Beginner (First-time user):
1. **SUMMARY_OF_CHANGES.md** - What changed? (5 min)
2. **INTERPRETING_FILTERING_LOGS.md** - How to read results (15 min)
3. **FILTERING_FAQ.md** - Bookmark for questions (as needed)

### Intermediate (Analyzing results):
1. Look at your filtering log output
2. Compare to examples in **INTERPRETING_FILTERING_LOGS.md**
3. Check **FILTERING_FAQ.md** for specific questions
4. Run **test_filtering_calculations.sh** to verify

### Advanced (Customizing/Troubleshooting):
1. **FILTERING_LOG_IMPROVEMENTS.md** - Technical details
2. **FILTERING_FAQ.md** - Q8 (changing thresholds), Q17-19 (advanced)
3. Review actual code in `modules/local/blacklist_log.nf`

---

## 🔧 Technical Summary

### Modified Files:

```
subworkflows/local/prepare_genome.nf
  └─ Added: emit blacklist file

modules/local/blacklist_log.nf
  └─ Rewritten: Separate statistics for each filter
  └─ Renamed: *.blacklist.log → *.filtering.log

workflows/chipseq.nf
  └─ Updated: BLACKLIST_LOG process call
```

### Key Changes:

1. **Accurate blacklist counting**: Uses `samtools view -c -L blacklist.bed`
2. **Separate duplicate counting**: Uses `samtools view -c -f 0x0400`
3. **Other filters calculated**: `TOTAL - DUPLICATES - BLACKLIST`
4. **Improved log format**: Clear breakdown with percentages

---

## 📖 Example Output

### New Filtering Log:
```
========================================================================
BAM FILTERING LOG - Sample: ENCFF123ABC
========================================================================

Date: 2026-04-14 14:53:09
Input BAM (MARK_DUPLICATES):   ENCFF123ABC.mLb.mkD.bam
Output BAM (after filtering):  ENCFF123ABC.mLb.mkD.filter2.bam
Blacklist file:                hg38.blacklist.bed

------------------------------------------------------------------------
FILTERING STATISTICS
------------------------------------------------------------------------

Total reads (input):                      10,000,000

Reads overlapping blacklist regions:       1,500,000  (15.00%)
Duplicate reads (marked by Picard):        3,000,000  (30.00%)
Reads removed by other filters*:           1,575,000  (15.75%)
  (*MAPQ < 1, fragment size > 500bp, secondary/supplementary alignments)

------------------------------------------------------------------------
TOTAL FILTERING IMPACT
------------------------------------------------------------------------

Total reads REMOVED (all filters):         6,075,000  (60.75%)
Total reads RETAINED:                      3,925,000  (39.25%)

Number of blacklist regions:                   1,234

------------------------------------------------------------------------
NOTE
------------------------------------------------------------------------
- Blacklist count shows reads overlapping blacklist regions
- Duplicate count shows reads marked by Picard MarkDuplicates
- Other filters include: multi-mappers (MAPQ<1), large fragments (>500bp),
  secondary/supplementary alignments, unmapped reads
- Some reads may be counted in multiple categories (e.g., a duplicate
  read in a blacklist region contributes to both counts)

========================================================================
```

---

## 🧪 Testing

### Run the test script:
```bash
cd chipseq
chmod +x test_filtering_calculations.sh
./test_filtering_calculations.sh
```

Expected output:
```
Total reads (input):                      10,000,000

Reads overlapping blacklist regions:       1,500,000  (15.00%)
Duplicate reads (marked by Picard):        3,000,000  (30.00%)
Reads removed by other filters*:           1,575,000  (15.75%)

Total reads REMOVED (all filters):         6,075,000  (60.75%)
Total reads RETAINED:                      3,925,000  (39.25%)

✅ Categories sum exactly to total removed
```

---

## 📍 Where to Find Results

After running the pipeline, filtering logs are located at:

```
<outdir>/<aligner>/mergedLibrary/filtering_metrics/*.filtering.log
```

Example:
```
results/bowtie2/mergedLibrary/filtering_metrics/sample1.filtering.log
results/bowtie2/mergedLibrary/filtering_metrics/sample2.filtering.log
```

---

## ❓ Common Questions

### Q: Why do percentages add up to more than 100%?
**A**: Categories can overlap. A read can be both a duplicate AND in a blacklist region. See **FAQ Q1**.

### Q: Is 60% retention good?
**A**: Generally yes! See **INTERPRETING_FILTERING_LOGS.md** - Quick Reference Table.

### Q: How can I change the filtering thresholds?
**A**: See **FAQ Q8** for detailed instructions.

### Q: The log file wasn't generated, why?
**A**: See **FAQ Q15** for troubleshooting steps.

### Q: Can I verify the calculations manually?
**A**: Yes! See **FAQ Q16** for a standalone script.

**More questions?** → Check **FILTERING_FAQ.md** (20+ Q&A)

---

## 🔍 Navigation Tips

### By Document Type:

- **Overview**: START HERE → **FILTERING_DOCUMENTATION_INDEX.md**
- **Quick summary**: **SUMMARY_OF_CHANGES.md**
- **Understanding results**: **INTERPRETING_FILTERING_LOGS.md**
- **Specific questions**: **FILTERING_FAQ.md**
- **Technical details**: **FILTERING_LOG_IMPROVEMENTS.md**
- **Testing**: **test_filtering_calculations.sh**

### By Use Case:

- **First time here?** → Start with **FILTERING_DOCUMENTATION_INDEX.md**
- **Just ran pipeline?** → Read **INTERPRETING_FILTERING_LOGS.md**
- **Something looks wrong?** → Check **FILTERING_FAQ.md**
- **Want to customize?** → See FAQ Q8 and **FILTERING_LOG_IMPROVEMENTS.md**
- **Need to verify?** → Run **test_filtering_calculations.sh**

---

## ✅ Benefits of These Improvements

| Before | After |
|--------|-------|
| ❌ Misleading label ("blacklist") | ✅ Accurate label ("filtering") |
| ❌ Combined all filters | ✅ Separated by filter type |
| ❌ No breakdown | ✅ Detailed breakdown with percentages |
| ❌ Hard to troubleshoot | ✅ Easy to identify problems |
| ❌ No documentation | ✅ Comprehensive docs + FAQ |

---

## 🎯 Key Takeaways

1. **New log format** separates filtering statistics by type
2. **Blacklist counting** is now accurate (15% vs. misleading 60%)
3. **Each filter** (blacklist, duplicates, other) is counted separately
4. **Comprehensive documentation** helps you interpret and troubleshoot
5. **Test script** validates the calculations

---

## 📞 Need Help?

1. **Check the docs**: Start with **FILTERING_DOCUMENTATION_INDEX.md**
2. **Search the FAQ**: **FILTERING_FAQ.md** has 20+ answers
3. **Test yourself**: Run **test_filtering_calculations.sh**
4. **External help**:
   - nf-core Slack: https://nf-co.re/join/slack
   - GitHub issues: https://github.com/nf-core/chipseq/issues

---

## 🙏 Credits

- **ENCODE Consortium**: Blacklist regions
- **Picard/GATK**: MarkDuplicates tool
- **SAMtools**: BAM manipulation
- **nf-core community**: Pipeline framework

---

## 📅 Version

**Initial release**: 2026-04-14

---

**Happy filtering! 🧬✨**

For detailed information, start with **FILTERING_DOCUMENTATION_INDEX.md**
