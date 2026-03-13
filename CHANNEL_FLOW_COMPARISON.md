# Channel Flow Comparison: STAR vs BOWTIE2

## STAR (Working - commit 101bb0d^)

### 1. Main Workflow Call
```groovy
ALIGN_STAR (
    ch_filtered_reads,                    // [meta, reads] - NO .collect()
    PREPARE_GENOME.out.star_index         // path - NO .collect()
)
```

### 2. ALIGN_STAR Subworkflow Signature
```groovy
workflow ALIGN_STAR {
    take:
    reads     // channel: [ val(meta), [ reads ] ]
    index     // channel: /path/to/star/index/
```

### 3. ALIGN_STAR → STAR_ALIGN Process Call
```groovy
STAR_ALIGN ( reads, index )
```

### 4. STAR_ALIGN Process Input
```groovy
process STAR_ALIGN {
    input:
    tuple val(meta), path(reads)
    path  index
```

### 5. PREPARE_GENOME Output
```groovy
emit:
    star_index = ch_star_index    // path: star/index/
```

---

## BOWTIE2 (Current Implementation)

### 1. Main Workflow Call
```groovy
FASTQ_ALIGN_BOWTIE2 (
    ch_filtered_reads,                    // [meta, reads] - NO .collect() ✅
    PREPARE_GENOME.out.bowtie2_index,     // path - NO .collect() ✅
    false,                                // save_unaligned
    false,                                // sort_bam
    PREPARE_GENOME.out.fasta              // path - NO .collect() ✅
)
```

### 2. FASTQ_ALIGN_BOWTIE2 Subworkflow Signature
```groovy
workflow FASTQ_ALIGN_BOWTIE2 {
    take:
    ch_reads          // channel: [ val(meta), [ reads ] ]
    ch_index          // channel: /path/to/bowtie2/index/
    save_unaligned    // val: boolean
    sort_bam          // val: boolean
    ch_fasta          // channel: /path/to/reference.fasta
```

### 3. FASTQ_ALIGN_BOWTIE2 → BOWTIE2_ALIGN Process Call
```groovy
BOWTIE2_ALIGN ( ch_reads, ch_index, ch_fasta, save_unaligned, sort_bam )
```

### 4. BOWTIE2_ALIGN Process Input
```groovy
process BOWTIE2_ALIGN {
    input:
    tuple val(meta), path(reads)
    path  index
    path  fasta
    val   save_unaligned
    val   sort_bam
```

### 5. PREPARE_GENOME Output
```groovy
emit:
    bowtie2_index = ch_bowtie2_index    // path: bowtie2/index/
    fasta         = ch_fasta            // path: genome.fasta
```

---

## Analysis: Channel Strategy Comparison

| Channel | STAR Strategy | BOWTIE2 Strategy | Match? |
|---------|---------------|------------------|--------|
| **reads** | `ch_filtered_reads` (no .collect()) | `ch_filtered_reads` (no .collect()) | ✅ MATCH |
| **index** | `PREPARE_GENOME.out.star_index` (no .collect()) | `PREPARE_GENOME.out.bowtie2_index` (no .collect()) | ✅ MATCH |
| **fasta** | N/A (not used by STAR) | `PREPARE_GENOME.out.fasta` (no .collect()) | ✅ CORRECT |

---

## Critical Differences

### STAR
- **2 parameters**: reads, index
- **Simple signature**: Only alignment essentials
- **No optional parameters**

### BOWTIE2
- **5 parameters**: reads, index, fasta, save_unaligned, sort_bam
- **More complex**: Requires fasta reference for CRAM support
- **Boolean flags**: Control output format and unaligned reads

---

## Validation Findings

### ✅ All Channels Follow STAR Pattern:
1. **ch_filtered_reads**: `[meta, reads]` tuple - NO `.collect()`
2. **bowtie2_index**: Simple path - NO `.collect()`
3. **fasta**: Simple path - NO `.collect()`

### 🔧 Fixed Issues:
1. ✅ Removed `.collect()` from `bowtie2_index` 
2. ✅ Removed `.collect()` from `fasta`
3. ✅ Replaced `.subscribe()` with `.view()` in validation to prevent channel consumption

### Why .collect() Was Wrong:
- **STAR never used `.collect()`** on any channel
- In DSL2, channels auto-fork when consumed by multiple processes
- `.collect()` groups all items into a single list, breaking `[meta, data]` structure
- For simple path channels, `.collect()` is unnecessary and can cause timing issues

### Why .subscribe() Was Wrong:
- `.subscribe()` is a **terminal operator** that consumes the channel
- Even in DSL2 with auto-forking, `.subscribe()` terminates that branch
- After `.subscribe()`, the channel is empty for downstream processes
- `.view()` is the correct choice - it doesn't consume, just displays

---

## Conclusion

✅ **BOWTIE2 now follows the exact same channel passing strategy as STAR**
✅ **No .collect() operators on any channels**
✅ **No .subscribe() operators that consume channels**
✅ **DSL2 auto-forking handles all channel distribution**
