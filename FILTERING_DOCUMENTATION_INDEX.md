# Filtering Log Documentation - Complete Index

## 📚 Documentation Overview

This directory contains comprehensive documentation about the improved BAM filtering log implementation in the nf-core/chipseq pipeline.

---

## 📖 Documents

### 1. **SUMMARY_OF_CHANGES.md** ⭐ START HERE
**Purpose**: Quick overview of what changed and why

**Contents**:
- Problem statement (before/after comparison)
- Files modified with specific changes
- New log output format
- Benefits table
- Quick start guide

**Best for**: 
- Understanding what was changed
- Getting started quickly
- Seeing code changes at a glance

**Read time**: ~5 minutes

---

### 2. **FILTERING_LOG_IMPROVEMENTS.md**
**Purpose**: Detailed technical explanation of the problem and solution

**Contents**:
- Detailed problem identification
- All filters applied in BAM_FILTER process
- BAM file comparisons (BEFORE vs AFTER)
- Solution implementation details
- Testing instructions

**Best for**:
- Understanding WHY the changes were made
- Technical deep-dive into the filtering logic
- Debugging issues

**Read time**: ~10 minutes

---

### 3. **INTERPRETING_FILTERING_LOGS.md** ⭐ RECOMMENDED
**Purpose**: How to understand and act on the filtering statistics

**Contents**:
- What each metric means
- Typical ranges for each metric
- Example scenarios (good, bad, problematic)
- Troubleshooting workflow
- Quick reference table
- Biological context

**Best for**:
- Understanding your results
- Identifying data quality issues
- Deciding if results are acceptable
- Comparing to expected ranges

**Read time**: ~15 minutes

---

### 4. **FILTERING_FAQ.md** ⭐ TROUBLESHOOTING
**Purpose**: Answers to common questions and problems

**Contents**:
- 20+ frequently asked questions
- Technical Q&A (how calculations work)
- Interpretation Q&A (what numbers mean)
- Troubleshooting Q&A (fixing problems)
- Advanced Q&A (customization, visualization)

**Best for**:
- Quick answers to specific questions
- Troubleshooting errors
- Understanding technical details
- Advanced usage

**Read time**: Browse as needed (~20-30 min to read fully)

---

### 5. **test_filtering_calculations.sh**
**Purpose**: Executable script to validate filtering calculations

**Contents**:
- Simulated filtering calculations
- Validation checks
- Instructions for use with real data

**Best for**:
- Testing the filtering logic
- Verifying your own calculations
- Understanding the math

**Usage**:
```bash
chmod +x test_filtering_calculations.sh
./test_filtering_calculations.sh
```

---

## 🚀 Quick Start Guide

### For First-Time Users:
1. **Read**: `SUMMARY_OF_CHANGES.md` (5 min)
2. **Understand**: `INTERPRETING_FILTERING_LOGS.md` - "Understanding the Numbers" section (5 min)
3. **Reference**: Keep `FILTERING_FAQ.md` handy for questions

### For Troubleshooting:
1. **Check**: Your filtering log output
2. **Compare**: To examples in `INTERPRETING_FILTERING_LOGS.md`
3. **Search**: `FILTERING_FAQ.md` for your specific issue
4. **Test**: Use `test_filtering_calculations.sh` to verify calculations

### For Advanced Users:
1. **Review**: `FILTERING_LOG_IMPROVEMENTS.md` for technical details
2. **Customize**: See FAQ Q8 for changing thresholds
3. **Validate**: Use FAQ Q17-Q19 for advanced analysis

---

## 📋 Modified Pipeline Files

These are the actual pipeline files that were modified:

### Core Changes:
1. **`subworkflows/local/prepare_genome.nf`**
   - Added `blacklist` to emit block
   - Passes original blacklist file to downstream processes

2. **`modules/local/blacklist_log.nf`**
   - Complete rewrite of calculation logic
   - Renamed output from `*.blacklist.log` to `*.filtering.log`
   - Added separate calculations for each filter type
   - Improved log format with detailed statistics

3. **`workflows/chipseq.nf`**
   - Added `PREPARE_GENOME.out.blacklist.first()` to BLACKLIST_LOG call
   - Updated process documentation

### Documentation:
- `SUMMARY_OF_CHANGES.md`
- `FILTERING_LOG_IMPROVEMENTS.md`
- `INTERPRETING_FILTERING_LOGS.md`
- `FILTERING_FAQ.md`
- `FILTERING_DOCUMENTATION_INDEX.md` (this file)

### Testing:
- `test_filtering_calculations.sh`

---

## 🎯 Common Use Cases

### Use Case 1: "I just ran the pipeline and want to understand my results"
**Path**: 
1. Open your filtering log: `results/bowtie2/mergedLibrary/filtering_metrics/*.filtering.log`
2. Read `INTERPRETING_FILTERING_LOGS.md` - "Understanding the Numbers"
3. Compare to "Quick Reference Table" in same document
4. Check if retention % is in acceptable range

### Use Case 2: "My retention rate is only 35%, is that bad?"
**Path**:
1. Check `INTERPRETING_FILTERING_LOGS.md` - Quick Reference Table (Yes, <40% needs action)
2. Look at example scenarios to match your situation
3. Read FAQ Q3: "Why is my retention rate so low?"
4. Follow troubleshooting workflow in `INTERPRETING_FILTERING_LOGS.md`

### Use Case 3: "I want to change the fragment size threshold"
**Path**:
1. Check FAQ Q8: "Can I change the filtering thresholds?"
2. Review `FILTERING_LOG_IMPROVEMENTS.md` for technical context
3. Edit `modules/local/bam_filter.nf` as described
4. Re-run pipeline and compare results

### Use Case 4: "The percentages don't add up, is something wrong?"
**Path**:
1. Read FAQ Q1: "Why do the percentages add up to more than 100%?"
2. Read FAQ Q11: "Can duplicates and blacklist overlap?"
3. Check FAQ Q14 for specific calculation questions

### Use Case 5: "I want to verify the calculations are correct"
**Path**:
1. Run `test_filtering_calculations.sh` with example data
2. Compare script logic to your actual log
3. See FAQ Q16 for manual calculation
4. Check FAQ Q17 for visualization options

---

## 🔍 Finding Information Quickly

### By Topic:

| Topic | Document | Section |
|-------|----------|---------|
| What changed? | SUMMARY_OF_CHANGES.md | Problem Statement, Files Modified |
| How to interpret results? | INTERPRETING_FILTERING_LOGS.md | Understanding the Numbers |
| What's a good retention %? | INTERPRETING_FILTERING_LOGS.md | Quick Reference Table |
| Why high duplication? | INTERPRETING_FILTERING_LOGS.md | Scenario 2; FAQ Q3 |
| Why high blacklist? | INTERPRETING_FILTERING_LOGS.md | Scenario 3; FAQ Q10 |
| How calculations work? | FILTERING_LOG_IMPROVEMENTS.md | Solution; FAQ Q5-Q7 |
| Change thresholds? | FAQ Q8 | - |
| Manual calculation? | FAQ Q16 | - |
| Percentages > 100%? | FAQ Q1, Q11, Q14 | - |
| Missing log file? | FAQ Q15 | - |
| Testing calculations? | test_filtering_calculations.sh | - |

---

## 📊 Example Workflow

### Scenario: Analyzing a new ChIP-seq experiment

```bash
# 1. Run the pipeline
nextflow run nf-core/chipseq \
    --input samplesheet.csv \
    --genome GRCh38 \
    --blacklist hg38.blacklist.bed

# 2. Check the filtering log
cat results/bowtie2/mergedLibrary/filtering_metrics/sample1.filtering.log

# 3. Interpret results using documentation
# Open: INTERPRETING_FILTERING_LOGS.md
# Compare your retention % to "Quick Reference Table"

# 4. If retention < 60%, troubleshoot:
# Read relevant scenario in INTERPRETING_FILTERING_LOGS.md
# Check FAQ for specific issue (high duplicates? high blacklist?)

# 5. Validate calculations (optional)
# Copy numbers from your log into test_filtering_calculations.sh
# Run and verify math is correct

# 6. Take action if needed:
# - High duplicates: Re-prep library with less PCR
# - High blacklist: Check blacklist file, verify antibody
# - High other filters: Examine MAPQ, fragment sizes
```

---

## 🛠️ Maintenance Guide

### If you need to modify the filtering logic:

1. **Edit**: `modules/local/blacklist_log.nf`
2. **Update**: Examples in `INTERPRETING_FILTERING_LOGS.md`
3. **Update**: Relevant FAQ entries in `FILTERING_FAQ.md`
4. **Test**: Modify `test_filtering_calculations.sh` to match new logic
5. **Document**: Add changes to `SUMMARY_OF_CHANGES.md` changelog

### If you find errors or have suggestions:

1. Check if already documented in FAQ
2. If new issue, add to appropriate FAQ section
3. If major change needed, update all affected documents
4. Consider adding new example scenarios to `INTERPRETING_FILTERING_LOGS.md`

---

## 📞 Getting Help

### Internal Documentation:
1. Start with this index to find relevant document
2. Check FAQ first for common questions
3. Read examples/scenarios for context
4. Test with provided scripts

### External Resources:
- **nf-core/chipseq docs**: https://nf-co.re/chipseq
- **nf-core Slack**: https://nf-co.re/join/slack
- **ENCODE guidelines**: https://www.encodeproject.org/chip-seq/
- **GitHub issues**: https://github.com/nf-core/chipseq/issues

---

## ✅ Document Checklist

Before considering documentation complete, verify:

- [ ] All files are present and readable
- [ ] Code examples are tested and working
- [ ] Cross-references between documents are correct
- [ ] FAQ covers common questions
- [ ] Examples match current implementation
- [ ] Quick reference tables are accurate
- [ ] Test script produces expected output
- [ ] Troubleshooting workflows are clear

---

## 📅 Version History

**2026-04-14 - Initial Release**:
- Created comprehensive filtering log documentation
- Implemented separated filtering statistics
- Added interpretation guide and FAQ
- Created test and validation scripts

---

## 📄 License

These documentation files accompany the nf-core/chipseq pipeline and follow the same MIT license.

---

## 🙏 Acknowledgments

- **ENCODE Consortium**: For blacklist regions and ChIP-seq guidelines
- **nf-core community**: For pipeline framework and best practices
- **Picard/GATK team**: For MarkDuplicates tool
- **SAMtools developers**: For BAM manipulation tools

---

**Happy filtering! 🧬🔬**

For questions or suggestions, please open an issue on the nf-core/chipseq GitHub repository.
