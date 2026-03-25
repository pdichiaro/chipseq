#!/bin/bash
# Minimal test for MultiQC nested sections with parent_id/parent_name

set -e

TEST_DIR="test_multiqc_nested"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "=== Creating test files with parent_id/parent_name ==="

# Create a simple test file with parent section
cat > 01_test_plot_mqc.txt <<'EOF'
#parent_id: 'deseq2-featurecounts-qc'
#parent_name: 'DESeq2 FeatureCounts QC'
#id: '01_deseq2_read_distribution_featurecounts_all_genes'
#section_name: '01. Read Distribution (All Genes)'
#plot_type: 'box'
#pconfig:
#    title: 'Read Distribution (All Genes)'
Sample_1	Sample_2	Sample_3
2.1	2.3	2.0
5.3	5.5	5.2
7.8	7.9	7.7
EOF

# Create another plot in the same parent
cat > 02_test_pca_mqc.txt <<'EOF'
#parent_id: 'deseq2-featurecounts-qc'
#parent_name: 'DESeq2 FeatureCounts QC'
#id: '02_deseq2_pca_featurecounts_all_genes'
#section_name: '02. PCA (All Genes)'
#plot_type: 'scatter'
#pconfig:
#    title: 'PCA (All Genes)'
#    xlab: 'PC1'
#    ylab: 'PC2'
	PC1	PC2
Sample_1	-12.5	8.3
Sample_2	-10.2	6.7
Sample_3	11.8	-5.2
EOF

echo ""
echo "Files created:"
ls -lh *_mqc.txt

echo ""
echo "First file content:"
cat 01_test_plot_mqc.txt

echo ""
echo "Running MultiQC..."
multiqc . -n test_nested_report.html -f -v

echo ""
echo "=== Test complete! ==="
echo "Check test_nested_report.html in test_multiqc_nested/"
echo ""
echo "If the 'DESeq2 FeatureCounts QC' parent section doesn't appear,"
echo "it means MultiQC doesn't support parent_id/parent_name syntax."
