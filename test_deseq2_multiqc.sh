#!/bin/bash
# Test script to verify DESeq2 MultiQC integration

set -e

echo "=== Testing DESeq2 MultiQC Integration ==="

# Create test directory
TEST_DIR="test_deseq2_mqc"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "1. Creating test DESeq2 data files..."

# Create sample read distribution file (box plot data)
cat > featureCounts.deseq2.all_genes.read.distribution.normalized.txt <<'EOF'
Sample_1	Sample_2	Sample_3	Sample_4
2.1	2.3	2.0	2.2
5.3	5.5	5.2	5.4
7.8	7.9	7.7	8.0
10.2	10.4	10.1	10.5
15.6	15.8	15.5	16.0
EOF

# Create sample distance file (heatmap data)
cat > featureCounts.deseq2.all_genes.sample.dists.txt <<'EOF'
	Sample_1	Sample_2	Sample_3	Sample_4
Sample_1	0	25.3	28.7	45.2
Sample_2	25.3	0	30.1	42.8
Sample_3	28.7	30.1	0	48.5
Sample_4	45.2	42.8	48.5	0
EOF

# Create PCA file (scatter plot data)
cat > featureCounts.deseq2.all_genes.pca.vals.txt <<'EOF'
	PC1	PC2
Sample_1	-12.5	8.3
Sample_2	-10.2	6.7
Sample_3	11.8	-5.2
Sample_4	13.1	-7.4
EOF

# Create PCA top genes file
cat > featureCounts.deseq2.all_genes.pca.top500.vals.txt <<'EOF'
	PC1	PC2
Sample_1	-15.2	10.1
Sample_2	-13.5	8.9
Sample_3	14.7	-7.3
Sample_4	16.3	-9.8
EOF

echo "2. Running DESEQ2_TRANSFORM logic..."

# Get absolute path to headers
HEADER_DIR="$(cd .. && pwd)/assets/multiqc"
echo "Header directory: $HEADER_DIR"

# Simulate what DESEQ2_TRANSFORM does
for file in featureCounts.deseq2.all_genes.*.txt; do
    echo "Processing: $file"
    
    file_name="$file"
    QUANTIFIER="deseq2-featurecounts-qc"
    QUANTIFIER_SHORT="featurecounts"
    PARENT_NAME="DESeq2 FeatureCounts QC"
    LEVEL="all_genes"
    SECTION_NAME="All Genes"
    OFFSET=0
    
    # Determine plot type and number
    if [[ "$file_name" == *".pca.top"*".vals.txt" ]]; then
        PLOT_NUM=$((4 + OFFSET))
        PLOT_ID="$(printf '%02d' $PLOT_NUM)_deseq2_pca_top500_${QUANTIFIER_SHORT}_${LEVEL}"
        SECTION_TITLE="$(printf '%02d' $PLOT_NUM). PCA Top 500 (${SECTION_NAME})"
        PLOT_TITLE="PCA Top 500 (${SECTION_NAME})"
        HEADER="$HEADER_DIR/deseq2_pca_header.txt"
    elif [[ "$file_name" == *".pca.vals.txt" ]]; then
        PLOT_NUM=$((3 + OFFSET))
        PLOT_ID="$(printf '%02d' $PLOT_NUM)_deseq2_pca_${QUANTIFIER_SHORT}_${LEVEL}"
        SECTION_TITLE="$(printf '%02d' $PLOT_NUM). PCA (${SECTION_NAME})"
        PLOT_TITLE="PCA (${SECTION_NAME})"
        HEADER="$HEADER_DIR/deseq2_pca_header.txt"
    elif [[ "$file_name" == *".sample.dists."* ]]; then
        PLOT_NUM=$((2 + OFFSET))
        PLOT_ID="$(printf '%02d' $PLOT_NUM)_deseq2_sample_distance_${QUANTIFIER_SHORT}_${LEVEL}"
        SECTION_TITLE="$(printf '%02d' $PLOT_NUM). Sample Distances (${SECTION_NAME})"
        PLOT_TITLE="Sample Distances (${SECTION_NAME})"
        HEADER="$HEADER_DIR/deseq2_clustering_header.txt"
    elif [[ "$file_name" == *".read.distribution.normalized."* ]]; then
        PLOT_NUM=$((1 + OFFSET))
        PLOT_ID="$(printf '%02d' $PLOT_NUM)_deseq2_read_distribution_${QUANTIFIER_SHORT}_${LEVEL}"
        SECTION_TITLE="$(printf '%02d' $PLOT_NUM). Read Distribution (${SECTION_NAME})"
        PLOT_TITLE="Read Distribution (${SECTION_NAME})"
        HEADER="$HEADER_DIR/deseq2_read_dist_header.txt"
    else
        echo "  Unknown file type, skipping"
        continue
    fi
    
    output_name="$(printf '%02d' $PLOT_NUM)_${file_name/.txt/_mqc.txt}"
    
    echo "  -> Creating: $output_name"
    echo "  -> Plot ID: $PLOT_ID"
    echo "  -> Parent: $QUANTIFIER"
    
    # Create the output file with modified header
    {
        sed "s|#section_anchor:.*|#parent_id: '${QUANTIFIER}'\n#parent_name: '${PARENT_NAME}'|; \
             s|#section_name:.*|#section_name: '${SECTION_TITLE}'|; \
             s|#id:.*|#id: '${PLOT_ID}'|; \
             s|title:.*|title: '${PLOT_TITLE}'|" "$HEADER"
        cat "$file"
    } > "$output_name"
    
    echo "  ✓ Created: $output_name"
done

echo ""
echo "3. Files created:"
ls -lh *_mqc.txt

echo ""
echo "4. Checking file content (first file):"
head -20 01_featureCounts.deseq2.all_genes.read.distribution.normalized_mqc.txt

echo ""
echo "5. Running MultiQC..."
multiqc . -n test_deseq2_report.html -f

echo ""
echo "=== Test complete! ==="
echo "Check test_deseq2_report.html to see if DESeq2 sections appear"
