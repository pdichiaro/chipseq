# Debug Statements Currently in the Pipeline

This document tracks all debug/logging statements added during troubleshooting.
These can be **kept** (they provide useful runtime information) or **removed** to clean up logs.

## Location: workflows/chipseq.nf

### Line 163: Bowtie2 Index Validation
```groovy
.view { index -> "✓ Bowtie2 index available: ${index}" }
```
**Purpose:** Confirms Bowtie2 index files are correctly prepared  
**Recommendation:** ✅ KEEP - Useful for verifying genome preparation

---

### Lines 198-215: Filtered Reads Validation Block
```groovy
//
// Validate and debug filtered reads channel
//
ch_filtered_reads_raw
    .map { meta, reads ->
        // Validate meta object has required fields
        if (!meta) {
            error "ERROR: meta object is null after trimming for reads: ${reads}"
        }
        if (!meta.containsKey('single_end')) {
            error "ERROR: meta object missing 'single_end' field for sample ${meta.id}"
        }
        if (!meta.containsKey('id')) {
            error "ERROR: meta object missing 'id' field"
        }
        
        log.info "✓ Sample ${meta.id} passed filtering: single_end=${meta.single_end}, reads=${reads.size()} file(s)"
        
        return [meta, reads]
    }
    .set { ch_filtered_reads }
```
**Purpose:** Validates metadata integrity after trimming, ensures required fields exist  
**Recommendation:** ✅ KEEP - Critical validation that prevents downstream failures

---

### Lines 386-387: IP-Control Matching Debug
```groovy
// DEBUG: Log successful matches
println "✓✓✓ MATCH: IP ${meta1.id} (which_input='${meta1.which_input}') + Control ${meta2.id}"
```
**Purpose:** Confirms correct pairing of ChIP samples with their input controls  
**Recommendation:** 🟡 OPTIONAL - Useful for debugging sample pairing issues, but verbose

---

### Line 536: MACS2 Success Confirmation
```groovy
log.info "✅ MACS2 peak calling successful for ${count} sample(s)"
```
**Purpose:** Reports successful peak calling completion  
**Recommendation:** ✅ KEEP - Good progress indicator

---

### Lines 792, 831: Scaling Factor Parsing
```groovy
log.info "🔍 SCALING PARSED: sample='${clean_id}', value='${value}'"
log.info "🔍 SCALING PARSED (all_genes): sample='${clean_id}', value='${value}'"
```
**Purpose:** Shows parsed scaling factors from DiffBind output  
**Recommendation:** 🟡 OPTIONAL - Useful for DESeq2 normalization debugging

---

### Lines 884, 891: Scaling Factor Channels
```groovy
log.info "📊 SCALING FACTOR (invariant): id='${id}', scaling=${scaling}"
log.info "📊 SCALING FACTOR (all_genes): id='${id}', scaling=${scaling}"
```
**Purpose:** Logs scaling factors being applied to each sample  
**Recommendation:** ✅ KEEP - Important for reproducibility and QC

---

### Lines 910, 926: Sample Matching for Normalization
```groovy
log.info "✅ MATCHED sample for invariant normalization: ${meta.id} (scaling=${scaling})"
log.info "✅ MATCHED sample for all_genes normalization: ${meta.id} (scaling=${scaling})"
```
**Purpose:** Confirms successful joining of samples with their scaling factors  
**Recommendation:** ✅ KEEP - Helps verify normalization is applied correctly

---

## Summary

### Recommended Actions:

**✅ KEEP (Production-Ready Logging):**
- Bowtie2 index validation (L163)
- Filtered reads validation block (L198-215) - **CRITICAL**
- MACS2 success message (L536)
- Scaling factor logs (L884, L891, L910, L926)

**🟡 OPTIONAL (Consider Removing for Cleaner Logs):**
- IP-Control matching debug (L386-387) - Very verbose
- Scaling parsing debug (L792, L831) - Only needed during DESeq2 troubleshooting

**❌ NO DEBUG STATEMENTS TO REMOVE:**
- The validation logic (error checks) should **always remain**
- The informational logging provides useful runtime feedback

---

## Nextflow Best Practices

### When to use `log.info`:
✅ Progress milestones (e.g., "Starting alignment...")  
✅ Important parameter values  
✅ Success confirmations  

### When to use `println`:
🟡 Temporary debugging (should be removed before production)  
🟡 Very verbose channel inspection  

### When to use `.view()`:
✅ Quick channel inspection during development  
🟡 Can remain if output is useful for users  

---

**Current Status:** All debug statements are providing **useful information**. The validation blocks (especially L198-215) should **never be removed** as they prevent cryptic downstream errors.

**Last Updated:** 2025-01-XX (after commits 5bb02d0 and 89099fa)
