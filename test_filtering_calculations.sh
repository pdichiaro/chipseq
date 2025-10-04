#!/bin/bash

# Test script to demonstrate filtering calculations
# This simulates what the BLACKLIST_LOG process does

echo "=========================================================================="
echo "FILTERING CALCULATION TEST"
echo "=========================================================================="
echo ""

# Simulated counts (replace with actual samtools counts from your BAMs)
READS_BEFORE=10000000
READS_AFTER=3925000
READS_IN_BLACKLIST=1500000
DUPLICATES_MARKED=3000000

echo "Input values (these would come from samtools view -c commands):"
echo "  READS_BEFORE (after MARK_DUPLICATES):  $(printf "%'d" $READS_BEFORE)"
echo "  READS_AFTER (after all filters):       $(printf "%'d" $READS_AFTER)"
echo "  READS_IN_BLACKLIST:                    $(printf "%'d" $READS_IN_BLACKLIST)"
echo "  DUPLICATES_MARKED:                     $(printf "%'d" $DUPLICATES_MARKED)"
echo ""

# Calculate total reads removed by ALL filters
TOTAL_REMOVED=$((READS_BEFORE - READS_AFTER))

# Calculate OTHER filters (MAPQ, fragment size, etc.)
# Note: Some reads may be in multiple categories (e.g., duplicate + blacklist)
OTHER_FILTERS=$((TOTAL_REMOVED - DUPLICATES_MARKED - READS_IN_BLACKLIST))

# Calculate percentages
PERCENT_BLACKLIST=$(awk "BEGIN {printf \"%.2f\", ($READS_IN_BLACKLIST / $READS_BEFORE) * 100}")
PERCENT_DUPLICATES=$(awk "BEGIN {printf \"%.2f\", ($DUPLICATES_MARKED / $READS_BEFORE) * 100}")
PERCENT_OTHER=$(awk "BEGIN {printf \"%.2f\", ($OTHER_FILTERS / $READS_BEFORE) * 100}")
PERCENT_TOTAL_REMOVED=$(awk "BEGIN {printf \"%.2f\", ($TOTAL_REMOVED / $READS_BEFORE) * 100}")
PERCENT_RETAINED=$(awk "BEGIN {printf \"%.2f\", ($READS_AFTER / $READS_BEFORE) * 100}")

echo "------------------------------------------------------------------------"
echo "CALCULATED STATISTICS"
echo "------------------------------------------------------------------------"
echo ""
echo "Reads overlapping blacklist regions:      $(printf "%15s" "$(printf "%'d" $READS_IN_BLACKLIST)")  (${PERCENT_BLACKLIST}%)"
echo "Duplicate reads (marked by Picard):       $(printf "%15s" "$(printf "%'d" $DUPLICATES_MARKED)")  (${PERCENT_DUPLICATES}%)"
echo "Reads removed by other filters*:          $(printf "%15s" "$(printf "%'d" $OTHER_FILTERS)")  (${PERCENT_OTHER}%)"
echo "  (*MAPQ < 1, fragment size > 500bp, secondary/supplementary)"
echo ""
echo "------------------------------------------------------------------------"
echo "TOTAL FILTERING IMPACT"
echo "------------------------------------------------------------------------"
echo ""
echo "Total reads REMOVED (all filters):        $(printf "%15s" "$(printf "%'d" $TOTAL_REMOVED)")  (${PERCENT_TOTAL_REMOVED}%)"
echo "Total reads RETAINED:                     $(printf "%15s" "$(printf "%'d" $READS_AFTER)")  (${PERCENT_RETAINED}%)"
echo ""

# Validation check
SUM_CATEGORIES=$((READS_IN_BLACKLIST + DUPLICATES_MARKED + OTHER_FILTERS))
echo "------------------------------------------------------------------------"
echo "VALIDATION"
echo "------------------------------------------------------------------------"
echo ""
echo "Sum of categories: $(printf "%'d" $SUM_CATEGORIES)"
echo "Total removed:     $(printf "%'d" $TOTAL_REMOVED)"
echo ""

if [ $SUM_CATEGORIES -eq $TOTAL_REMOVED ]; then
    echo "✅ Categories sum exactly to total removed (no overlap detected)"
elif [ $SUM_CATEGORIES -gt $TOTAL_REMOVED ]; then
    OVERLAP=$((SUM_CATEGORIES - TOTAL_REMOVED))
    echo "⚠️  Categories sum is GREATER than total removed"
    echo "    Overlap: $(printf "%'d" $OVERLAP) reads (${PERCENT_BLACKLIST}% + ${PERCENT_DUPLICATES}% + ${PERCENT_OTHER}% > ${PERCENT_TOTAL_REMOVED}%)"
    echo "    This indicates some reads belong to multiple categories"
    echo "    Example: A duplicate read in a blacklist region is counted in both categories"
else
    echo "❌ ERROR: Categories sum is LESS than total removed (this shouldn't happen)"
fi

echo ""
echo "=========================================================================="
echo "HOW TO USE WITH YOUR DATA"
echo "=========================================================================="
echo ""
echo "1. Get counts from your BAMs:"
echo "   READS_BEFORE=\$(samtools view -c sample.mLb.mkD.bam)"
echo "   READS_AFTER=\$(samtools view -c sample.mLb.mkD.filter2.bam)"
echo "   READS_IN_BLACKLIST=\$(samtools view -c -L blacklist.bed sample.mLb.mkD.bam)"
echo "   DUPLICATES_MARKED=\$(samtools view -c -f 0x0400 sample.mLb.mkD.bam)"
echo ""
echo "2. Replace the values in this script"
echo ""
echo "3. Run: bash test_filtering_calculations.sh"
echo ""
echo "=========================================================================="
