#!/bin/bash

# Test file names
files=(
    "featureCounts.all_genes.read.distribution.normalized.txt"
    "featureCounts.invariant_genes.read.distribution.normalized.txt"
    "featureCounts.all_genes.sample.distances.normalized.txt"
    "featureCounts.all_genes.pca.all_genes.normalized.txt"
)

echo "Testing pattern matching:"
for file_name in "${files[@]}"; do
    echo ""
    echo "File: $file_name"
    
    if [[ "$file_name" == *".read.distribution.normalized.txt" ]]; then
        echo "  ✓ Matches read distribution pattern"
    elif [[ "$file_name" == *".sample.distances.normalized.txt" ]]; then
        echo "  ✓ Matches sample distances pattern"
    elif [[ "$file_name" == *".pca."*".normalized.txt" ]]; then
        echo "  ✓ Matches PCA pattern"
    else
        echo "  ✗ No match"
    fi
done
