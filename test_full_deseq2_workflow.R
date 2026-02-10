#!/usr/bin/env Rscript

# Complete test of featureCounts → DESeq2 workflow
# Tests the full parsing and DESeq2 object creation

suppressPackageStartupMessages({
    library(DESeq2)
})

cat("=== COMPLETE WORKFLOW TEST: featureCounts → DESeq2 ===\n\n")

# Read featureCounts output
count_file <- "test_featurecounts_format.txt"
count.table <- read.delim(file=count_file, header=TRUE, row.names=NULL, comment.char="#")

cat("Step 1: Load Data\n")
cat("  Dimensions:", nrow(count.table), "genes x", ncol(count.table), "columns\n\n")

# Apply correct parsing (count_col = 7)
count_col <- 7
id_col <- 1

cat("Step 2: Parse with count_col =", count_col, "\n")

# Set row names
rownames(count.table) <- count.table[, id_col]

# Safety check
if (count_col > ncol(count.table)) {
    stop("ERROR: count_col exceeds number of columns!")
}

# Extract annotations
annotation_cols <- colnames(count.table)[1:(count_col-1)]
sample_cols <- colnames(count.table)[count_col:ncol(count.table)]

cat("  Annotation columns:", paste(annotation_cols, collapse=", "), "\n")
cat("  Sample columns:", paste(sample_cols, collapse=", "), "\n\n")

# Keep full table with annotations for later
full_count_table <- count.table
annotation_from_input <- count.table[, annotation_cols, drop=FALSE]

# Extract count matrix (samples only)
count.table <- count.table[, count_col:ncol(count.table), drop=FALSE]

# Clean sample names (remove .bam suffix)
colnames(count.table) <- gsub("\\.bam$", "", colnames(count.table))

cat("Step 3: Clean Sample Names\n")
cat("  New column names:", paste(colnames(count.table), collapse=", "), "\n\n")

# Verify all numeric
cat("Step 4: Validate Data Types\n")
is_numeric <- sapply(count.table, is.numeric)
if (all(is_numeric)) {
    cat("  ✓ All columns are numeric\n\n")
} else {
    cat("  ✗ ERROR: Non-numeric columns detected!\n")
    print(is_numeric)
    stop("Cannot proceed with non-numeric data")
}

# Create sample metadata (required for DESeq2)
cat("Step 5: Create Sample Metadata\n")
sample_names <- colnames(count.table)
coldata <- data.frame(
    sample_id = sample_names,
    condition = "control",  # Dummy condition for test
    row.names = sample_names
)
cat("  Sample metadata:\n")
print(coldata)
cat("\n")

# Create DESeqDataSet
cat("Step 6: Create DESeqDataSet Object\n")
tryCatch({
    dds <- DESeqDataSetFromMatrix(
        countData = count.table,
        colData = coldata,
        design = ~ 1  # No design for normalization-only
    )
    cat("  ✓ DESeqDataSet created successfully!\n")
    cat("  Object dimensions:", nrow(dds), "genes x", ncol(dds), "samples\n\n")
    
    # Test size factor calculation (core of DESeq2 normalization)
    cat("Step 7: Calculate Size Factors\n")
    dds <- estimateSizeFactors(dds)
    size_factors <- sizeFactors(dds)
    cat("  Size factors:\n")
    print(size_factors)
    cat("\n")
    
    # Get normalized counts
    cat("Step 8: Extract Normalized Counts\n")
    normalized_counts <- counts(dds, normalized=TRUE)
    cat("  Normalized count matrix dimensions:", 
        nrow(normalized_counts), "x", ncol(normalized_counts), "\n")
    cat("  First row preview:\n")
    print(normalized_counts[1, , drop=FALSE])
    cat("\n")
    
    cat("✓✓✓ SUCCESS: Complete workflow executed without errors! ✓✓✓\n\n")
    cat("CONCLUSION:\n")
    cat("  - featureCounts output parsed correctly with count_col=7\n")
    cat("  - All sample columns are numeric\n")
    cat("  - DESeqDataSet object created successfully\n")
    cat("  - Size factors calculated\n")
    cat("  - Normalized counts extracted\n")
    cat("  → Pipeline is compatible and ready for production use\n")
    
}, error = function(e) {
    cat("  ✗ ERROR creating DESeqDataSet:\n")
    cat("  ", conditionMessage(e), "\n\n")
    cat("DIAGNOSIS:\n")
    cat("  This error indicates incompatibility between count data and DESeq2\n")
    cat("  Check that:\n")
    cat("    1. All count columns are numeric\n")
    cat("    2. No annotation columns included in count matrix\n")
    cat("    3. count_col parameter set correctly\n")
    quit(status = 1)
})
