#!/bin/bash

# Test script for plot_peak_intersect.r
# Tests various scenarios with simulated data

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLOT_SCRIPT="${SCRIPT_DIR}/../bin/plot_peak_intersect.r"
OUTPUT_DIR="${SCRIPT_DIR}/output"

# Create output directory
mkdir -p "${OUTPUT_DIR}"

echo "======================================"
echo "Testing plot_peak_intersect.r"
echo "======================================"
echo ""

# Test 1: 3 samples - typical ChIP-seq experiment
echo "Test 1: 3 samples (typical experiment)"
echo "--------------------------------------"
Rscript "${PLOT_SCRIPT}" \
    -i "${SCRIPT_DIR}/test_data_3samples.txt" \
    -o "${OUTPUT_DIR}/upset_3samples.pdf"
echo "✓ Test 1 completed: ${OUTPUT_DIR}/upset_3samples.pdf"
echo ""

# Test 2: 5 samples - larger experiment
echo "Test 2: 5 samples (larger experiment)"
echo "--------------------------------------"
Rscript "${PLOT_SCRIPT}" \
    -i "${SCRIPT_DIR}/test_data_5samples.txt" \
    -o "${OUTPUT_DIR}/upset_5samples.pdf"
echo "✓ Test 2 completed: ${OUTPUT_DIR}/upset_5samples.pdf"
echo ""

# Test 3: Edge case - minimum 2 samples
echo "Test 3: Edge case - 2 samples (minimum)"
echo "--------------------------------------"
Rscript "${PLOT_SCRIPT}" \
    -i "${SCRIPT_DIR}/test_data_edge_case_2samples.txt" \
    -o "${OUTPUT_DIR}/upset_2samples.pdf"
echo "✓ Test 3 completed: ${OUTPUT_DIR}/upset_2samples.pdf"
echo ""

# Test 4: Edge case - insufficient data (should create placeholder)
echo "Test 4: Edge case - insufficient data"
echo "--------------------------------------"
Rscript "${PLOT_SCRIPT}" \
    -i "${SCRIPT_DIR}/test_data_edge_case_insufficient.txt" \
    -o "${OUTPUT_DIR}/upset_insufficient.pdf"
echo "✓ Test 4 completed: ${OUTPUT_DIR}/upset_insufficient.pdf (placeholder expected)"
echo ""

echo "======================================"
echo "All tests completed successfully!"
echo "======================================"
echo ""
echo "Output files:"
ls -lh "${OUTPUT_DIR}"/*.pdf
echo ""
echo "To view the PDFs, download them from the sandbox:"
echo "  ${OUTPUT_DIR}/upset_3samples.pdf"
echo "  ${OUTPUT_DIR}/upset_5samples.pdf"
echo "  ${OUTPUT_DIR}/upset_2samples.pdf"
echo "  ${OUTPUT_DIR}/upset_insufficient.pdf"
