#!/usr/bin/env Rscript

# Test script to verify featureCounts format parsing compatibility
# Simulates the parsing logic from normalize_deseq2_qc_invariant_genes.r

cat("=== Testing featureCounts Format Parsing ===\n\n")

# Read the test featureCounts file
count_file <- "test_featurecounts_format.txt"
count.table <- read.delim(file=count_file, header=TRUE, row.names=NULL, comment.char="#")

cat("1. INITIAL DATA STRUCTURE:\n")
cat("   Dimensions:", nrow(count.table), "rows x", ncol(count.table), "columns\n")
cat("   Column names:", paste(colnames(count.table), collapse=", "), "\n\n")

# Test with different count_col values
test_count_cols <- c(2, 7, 20)

for (count_col in test_count_cols) {
    cat("========================================\n")
    cat("TESTING with count_col =", count_col, "\n")
    cat("========================================\n")
    
    # Set up rownames
    id_col <- 1
    test_table <- count.table
    rownames(test_table) <- test_table[, id_col]
    
    # Safety check (from the R script)
    if (count_col > ncol(test_table)) {
        cat("⚠️  WARNING: count_col (", count_col, ") > ncol (", ncol(test_table), ")\n")
        cat("   → Resetting count_col to 2\n")
        count_col <- 2
    }
    
    # Extract column ranges
    annotation_cols <- colnames(test_table)[1:(count_col-1)]
    sample_cols <- colnames(test_table)[count_col:ncol(test_table)]
    
    cat("\n2. COLUMN CLASSIFICATION:\n")
    cat("   Annotation columns (1 to", count_col-1, "):\n")
    cat("     ", paste(annotation_cols, collapse=", "), "\n")
    cat("   Sample columns (", count_col, "to", ncol(test_table), "):\n")
    cat("     ", paste(sample_cols, collapse=", "), "\n")
    
    # Extract sample data
    sample_data <- test_table[, count_col:ncol(test_table), drop=FALSE]
    
    cat("\n3. EXTRACTED SAMPLE DATA:\n")
    cat("   Dimensions:", nrow(sample_data), "rows x", ncol(sample_data), "columns\n")
    cat("   Column names:", paste(colnames(sample_data), collapse=", "), "\n")
    cat("   First row values:", paste(sample_data[1,], collapse=", "), "\n")
    
    # Check if data is numeric
    is_numeric <- sapply(sample_data, is.numeric)
    cat("\n4. DATA TYPE CHECK:\n")
    for (i in 1:ncol(sample_data)) {
        cat("   ", colnames(sample_data)[i], "→", 
            ifelse(is_numeric[i], "✓ NUMERIC", "✗ NOT NUMERIC"), "\n")
    }
    
    # Try to create a simple count matrix
    cat("\n5. COUNT MATRIX PREVIEW:\n")
    if (all(is_numeric)) {
        cat("   ✓ All columns are numeric - suitable for DESeq2\n")
        cat("   First 3 rows:\n")
        print(head(sample_data, 3))
    } else {
        cat("   ✗ PROBLEM: Non-numeric columns detected!\n")
        cat("   → This will cause DESeq2 to fail\n")
    }
    
    cat("\n")
}

cat("=== RECOMMENDATION ===\n")
cat("For featureCounts output with 6 annotation columns:\n")
cat("  → Use count_col = 7 (first sample is column 7)\n")
cat("  → Default count_col = 2 will include Chr, Start, End, Strand, Length as 'samples'\n\n")

cat("=== CORRECT CONFIGURATION ===\n")
cat("In modules/local/normalize_deseq2_qc_invariant_genes/main.nf:\n")
cat("  normalize_deseq2_qc_invariant_genes.r \\\\\n")
cat("      --count_file $counts \\\\\n")
cat("      --count_col 7 \\\\          # <-- ADD THIS LINE\n")
cat("      --outdir ./ \\\\\n")
cat("      ...\n")
