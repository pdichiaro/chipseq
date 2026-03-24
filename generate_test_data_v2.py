#!/usr/bin/env python3
"""Generate synthetic MultiQC test data for DESeq2 sections with embedded headers"""

import yaml
from pathlib import Path

# Define test data directory
test_dir = Path("test_multiqc_data")
test_dir.mkdir(exist_ok=True)

# Sample names
samples = ["Sample_1", "Sample_2", "Sample_3", "Sample_4"]

def write_yaml_with_header(filepath, header_lines, data):
    """Write YAML file with comment header"""
    with open(filepath, 'w') as f:
        # Write header as comments
        for line in header_lines:
            f.write(f"#{line}\n")
        # Write data
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)

# 1. ALL GENES - Read Distribution (box plot)
header_all_genes_read_dist = [
    "id: 'deseq2_all_genes_read_dist'",
    "section_name: 'ALL GENES: 1. Read Distribution (Normalized)'",
    "section_anchor: 'deseq2-all-genes-qc'",
    "description: 'Distribution of normalized read counts across all genes for each sample. Values are variance-stabilized transformation (VST) normalized using DESeq2. Normalization method: all genes.'",
    "plot_type: 'box'",
    "pconfig:",
    "    title: 'DESeq2 All Genes: Normalized Read Distribution'",
    "    ylab: 'VST Normalized Counts'"
]

data_all_genes_read_dist = {
    "Sample_1": {"min": 2.1, "q1": 5.3, "median": 7.8, "q3": 10.2, "max": 15.6, "mean": 8.1},
    "Sample_2": {"min": 2.3, "q1": 5.5, "median": 7.9, "q3": 10.4, "max": 15.8, "mean": 8.2},
    "Sample_3": {"min": 2.0, "q1": 5.2, "median": 7.7, "q3": 10.1, "max": 15.5, "mean": 8.0},
    "Sample_4": {"min": 2.2, "q1": 5.4, "median": 8.0, "q3": 10.5, "max": 16.0, "mean": 8.3}
}

# 2. ALL GENES - Sample Distance (heatmap)
header_all_genes_sample_dist = [
    "id: 'deseq2_all_genes_sample_dist'",
    "section_name: 'ALL GENES: 2. Sample Distance'",
    "section_anchor: 'deseq2-all-genes-qc'",
    "description: 'Sample-to-sample distance heatmap based on Euclidean distances. Values are calculated using DESeq2 variance-stabilizing transformation. Normalization method: all genes.'",
    "plot_type: 'heatmap'",
    "pconfig:",
    "    title: 'DESeq2 All Genes: Sample-to-Sample Distances'",
    "    square: true"
]

data_all_genes_sample_dist = {
    "Sample_1": {"Sample_1": 0, "Sample_2": 25.3, "Sample_3": 28.7, "Sample_4": 45.2},
    "Sample_2": {"Sample_1": 25.3, "Sample_2": 0, "Sample_3": 30.1, "Sample_4": 42.8},
    "Sample_3": {"Sample_1": 28.7, "Sample_2": 30.1, "Sample_3": 0, "Sample_4": 48.5},
    "Sample_4": {"Sample_1": 45.2, "Sample_2": 42.8, "Sample_3": 48.5, "Sample_4": 0}
}

# 3. ALL GENES - PCA All Genes (scatter)
header_all_genes_pca_all = [
    "id: 'deseq2_all_genes_pca_all'",
    "section_name: 'ALL GENES: 3. PCA Plot (All Genes)'",
    "section_anchor: 'deseq2-all-genes-qc'",
    "description: 'Principal component analysis (PCA) plot using all genes. Values are calculated using DESeq2 variance-stabilizing transformation. Normalization method: all genes.'",
    "plot_type: 'scatter'",
    "pconfig:",
    "    title: 'DESeq2 All Genes: PCA (All Genes)'",
    "    xlab: 'PC1'",
    "    ylab: 'PC2'"
]

data_all_genes_pca_all = {
    "Sample_1": {"x": -12.5, "y": 8.3},
    "Sample_2": {"x": -10.2, "y": 6.7},
    "Sample_3": {"x": 11.8, "y": -5.2},
    "Sample_4": {"x": 13.1, "y": -7.4}
}

# 4. ALL GENES - PCA Top Genes (scatter)
header_all_genes_pca_top = [
    "id: 'deseq2_all_genes_pca_top'",
    "section_name: 'ALL GENES: 4. PCA Plot (Top Genes)'",
    "section_anchor: 'deseq2-all-genes-qc'",
    "description: 'Principal component analysis (PCA) plot using top variable genes. Values are calculated using DESeq2 variance-stabilizing transformation. Normalization method: all genes.'",
    "plot_type: 'scatter'",
    "pconfig:",
    "    title: 'DESeq2 All Genes: PCA (Top Variable Genes)'",
    "    xlab: 'PC1'",
    "    ylab: 'PC2'"
]

data_all_genes_pca_top = {
    "Sample_1": {"x": -15.2, "y": 10.1},
    "Sample_2": {"x": -13.5, "y": 8.9},
    "Sample_3": {"x": 14.7, "y": -7.3},
    "Sample_4": {"x": 16.3, "y": -9.8}
}

# 5. INVARIANT GENES - Read Distribution
header_inv_genes_read_dist = [
    "id: 'deseq2_invariant_genes_read_dist'",
    "section_name: 'INVARIANT GENES: 1. Read Distribution (Normalized)'",
    "section_anchor: 'deseq2-invariant-genes-qc'",
    "description: 'Distribution of normalized read counts across all genes for each sample. Values are variance-stabilized transformation (VST) normalized using DESeq2. Normalization method: invariant genes.'",
    "plot_type: 'box'",
    "pconfig:",
    "    title: 'DESeq2 Invariant Genes: Normalized Read Distribution'",
    "    ylab: 'VST Normalized Counts'"
]

data_inv_genes_read_dist = {
    "Sample_1": {"min": 2.0, "q1": 5.1, "median": 7.6, "q3": 10.0, "max": 15.3, "mean": 7.9},
    "Sample_2": {"min": 2.1, "q1": 5.2, "median": 7.7, "q3": 10.2, "max": 15.5, "mean": 8.0},
    "Sample_3": {"min": 1.9, "q1": 5.0, "median": 7.5, "q3": 9.9, "max": 15.2, "mean": 7.8},
    "Sample_4": {"min": 2.0, "q1": 5.1, "median": 7.8, "q3": 10.3, "max": 15.7, "mean": 8.1}
}

# 6. INVARIANT GENES - Sample Distance
header_inv_genes_sample_dist = [
    "id: 'deseq2_invariant_genes_sample_dist'",
    "section_name: 'INVARIANT GENES: 2. Sample Distance'",
    "section_anchor: 'deseq2-invariant-genes-qc'",
    "description: 'Sample-to-sample distance heatmap based on Euclidean distances. Values are calculated using DESeq2 variance-stabilizing transformation. Normalization method: invariant genes.'",
    "plot_type: 'heatmap'",
    "pconfig:",
    "    title: 'DESeq2 Invariant Genes: Sample-to-Sample Distances'",
    "    square: true"
]

data_inv_genes_sample_dist = {
    "Sample_1": {"Sample_1": 0, "Sample_2": 23.8, "Sample_3": 27.2, "Sample_4": 43.5},
    "Sample_2": {"Sample_1": 23.8, "Sample_2": 0, "Sample_3": 28.9, "Sample_4": 41.2},
    "Sample_3": {"Sample_1": 27.2, "Sample_2": 28.9, "Sample_3": 0, "Sample_4": 46.8},
    "Sample_4": {"Sample_1": 43.5, "Sample_2": 41.2, "Sample_3": 46.8, "Sample_4": 0}
}

# 7. INVARIANT GENES - PCA All Genes
header_inv_genes_pca_all = [
    "id: 'deseq2_invariant_genes_pca_all'",
    "section_name: 'INVARIANT GENES: 3. PCA Plot (All Genes)'",
    "section_anchor: 'deseq2-invariant-genes-qc'",
    "description: 'Principal component analysis (PCA) plot using all genes. Values are calculated using DESeq2 variance-stabilizing transformation. Normalization method: invariant genes.'",
    "plot_type: 'scatter'",
    "pconfig:",
    "    title: 'DESeq2 Invariant Genes: PCA (All Genes)'",
    "    xlab: 'PC1'",
    "    ylab: 'PC2'"
]

data_inv_genes_pca_all = {
    "Sample_1": {"x": -11.8, "y": 7.9},
    "Sample_2": {"x": -9.7, "y": 6.3},
    "Sample_3": {"x": 10.9, "y": -4.8},
    "Sample_4": {"x": 12.5, "y": -7.0}
}

# 8. INVARIANT GENES - PCA Top Genes
header_inv_genes_pca_top = [
    "id: 'deseq2_invariant_genes_pca_top'",
    "section_name: 'INVARIANT GENES: 4. PCA Plot (Top Genes)'",
    "section_anchor: 'deseq2-invariant-genes-qc'",
    "description: 'Principal component analysis (PCA) plot using top variable genes. Values are calculated using DESeq2 variance-stabilizing transformation. Normalization method: invariant genes.'",
    "plot_type: 'scatter'",
    "pconfig:",
    "    title: 'DESeq2 Invariant Genes: PCA (Top Variable Genes)'",
    "    xlab: 'PC1'",
    "    ylab: 'PC2'"
]

data_inv_genes_pca_top = {
    "Sample_1": {"x": -14.3, "y": 9.5},
    "Sample_2": {"x": -12.8, "y": 8.2},
    "Sample_3": {"x": 13.9, "y": -6.8},
    "Sample_4": {"x": 15.6, "y": -9.2}
}

# Write all data files with headers
datasets = [
    ("deseq2_all_genes_read_dist_mqc.yaml", header_all_genes_read_dist, data_all_genes_read_dist),
    ("deseq2_all_genes_sample_dist_mqc.yaml", header_all_genes_sample_dist, data_all_genes_sample_dist),
    ("deseq2_all_genes_pca_all_mqc.yaml", header_all_genes_pca_all, data_all_genes_pca_all),
    ("deseq2_all_genes_pca_top_mqc.yaml", header_all_genes_pca_top, data_all_genes_pca_top),
    ("deseq2_invariant_genes_read_dist_mqc.yaml", header_inv_genes_read_dist, data_inv_genes_read_dist),
    ("deseq2_invariant_genes_sample_dist_mqc.yaml", header_inv_genes_sample_dist, data_inv_genes_sample_dist),
    ("deseq2_invariant_genes_pca_all_mqc.yaml", header_inv_genes_pca_all, data_inv_genes_pca_all),
    ("deseq2_invariant_genes_pca_top_mqc.yaml", header_inv_genes_pca_top, data_inv_genes_pca_top)
]

for filename, header, data in datasets:
    filepath = test_dir / filename
    write_yaml_with_header(filepath, header, data)
    print(f"Created: {filepath}")

print("\nTest data generation complete!")
