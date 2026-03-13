# Fix for BOWTIE2_ALIGN Null Meta Object Error

## Problem Description
The pipeline was failing with the error:
```
Cannot get property 'single_end' on null object
```
at line 31 of `bowtie2/align/main.nf`, indicating that the `meta` object was null when BOWTIE2_ALIGN tried to access `meta.single_end`.

## Root Cause Analysis

After thorough investigation comparing **pdichiaro/chipseq** fork with **nf-core/chipseq** original, the root cause was identified:

### Channel Structure Mismatch

The `BOWTIE2_ALIGN` process expects **THREE tuple inputs**:
```groovy
input:
tuple val(meta) , path(reads)   // ← reads with metadata
tuple val(meta2), path(index)   // ← index with metadata
tuple val(meta3), path(fasta)   // ← fasta with metadata
```

### What Was Wrong in pdichiaro Fork (Before Fix):

1. ✅ `ch_bowtie2_index` was correctly emitted as tuple `[[:], path]` from `PREPARE_GENOME`
2. ✅ `ch_fasta` was correctly emitted as simple `path` from `PREPARE_GENOME`
3. ❌ **But**: `ch_fasta` was **NOT** converted to tuple in the main workflow
4. ❌ **Result**: `BOWTIE2_ALIGN` received a simple path instead of tuple `[meta, path]`, causing the null meta error

### What nf-core Does (Correct Implementation):

1. `PREPARE_GENOME` emits `bowtie2_index` as tuple `[[:], path]`
2. `PREPARE_GENOME` emits `fasta` as simple `path`
3. **In the main workflow**, `ch_fasta` is converted to tuple **before** passing to `FASTQ_ALIGN_BOWTIE2`:
   ```groovy
   FASTQ_ALIGN_BOWTIE2 (
       reads,
       ch_bowtie2_index,        // tuple [[:], path]
       save_unaligned,
       sort_bam,
       ch_fasta.map { [ [:], it ] }  // ← CONVERTED TO TUPLE!
   )
   ```

## Solution Applied

### Summary
The fix aligns the pdichiaro fork with the nf-core original implementation by ensuring **all inputs to BOWTIE2_ALIGN are tuples**.

### Changes Made

#### 1. `subworkflows/local/prepare_genome.nf` (line 151)

**Before (INCORRECT - was extracting path from tuple):**
```groovy
emit:
    bowtie2_index  = ch_bowtie2_index.map { _meta, idx -> idx }  // Extract path
```

**After (CORRECT - keep as tuple):**
```groovy
emit:
    bowtie2_index  = ch_bowtie2_index  // channel: [ val(meta), path(index) ]
```

**Why**: Must emit tuple `[meta, path]` because `BOWTIE2_ALIGN` expects `tuple val(meta2), path(index)`

---

#### 2. `workflows/chipseq.nf` (lines 222-233)

**Before (INCORRECT - missing tuple conversion for fasta):**
```groovy
FASTQ_ALIGN_BOWTIE2 (
    ch_filtered_reads,
    PREPARE_GENOME.out.bowtie2_index,  // tuple [[:], path]
    false,
    false,
    PREPARE_GENOME.out.fasta  // ← PROBLEM: simple path, not tuple!
)
```

**After (CORRECT - convert fasta to tuple):**
```groovy
FASTQ_ALIGN_BOWTIE2 (
    ch_filtered_reads,
    PREPARE_GENOME.out.bowtie2_index,  // tuple [[:], path]
    false,
    false,
    PREPARE_GENOME.out.fasta
        .map {
            [ [:], it ]  // ← FIXED: convert to tuple [meta, path]
        }
)
```

**Why**: `BOWTIE2_ALIGN` expects `tuple val(meta3), path(fasta)`, so we must convert the simple path to tuple format

---

#### 3. `subworkflows/nf-core/fastq_align_bowtie2.nf` (lines 8-14)

**Before (INCORRECT - wrong documentation):**
```groovy
workflow FASTQ_ALIGN_BOWTIE2 {
    take:
    ch_reads          // channel: [ val(meta), [ reads ] ]
    ch_index          // channel: path(index) - path only
    save_unaligned    // val: boolean
    sort_bam          // val: boolean
    ch_fasta          // channel: /path/to/reference.fasta
```

**After (CORRECT - updated documentation):**
```groovy
workflow FASTQ_ALIGN_BOWTIE2 {
    take:
    ch_reads          // channel: [ val(meta), [ reads ] ]
    ch_index          // channel: [ val(meta), path(index) ]
    save_unaligned    // val: boolean
    sort_bam          // val: boolean
    ch_fasta          // channel: [ val(meta), path(fasta) ]
```

**Why**: Documentation must accurately reflect that both `ch_index` and `ch_fasta` are tuples

---

## Why This Fix Works

### 1. **Matches nf-core Implementation Exactly**
The fix replicates nf-core's channel handling:
- `PREPARE_GENOME` emits `bowtie2_index` as tuple
- `PREPARE_GENOME` emits `fasta` as simple path
- Main workflow converts `fasta` to tuple before passing to subworkflow

### 2. **Satisfies BOWTIE2_ALIGN Input Requirements**
All three inputs are now tuples as expected:
```groovy
BOWTIE2_ALIGN (
    ch_reads,     // tuple val(meta), path(reads)   ✅
    ch_index,     // tuple val(meta2), path(index)  ✅
    ch_fasta,     // tuple val(meta3), path(fasta)  ✅
    save_unaligned,
    sort_bam
)
```

### 3. **Prevents Null Meta Errors**
The process can now safely access `meta.single_end`, `meta2`, and `meta3` without null pointer exceptions

### 4. **Enables Channel Reuse**
Tuple channels can be safely consumed multiple times without `.first()` operators that cause race conditions

## Comparison: nf-core vs pdichiaro (Fixed)

| Component | nf-core/chipseq | pdichiaro/chipseq (BEFORE) | pdichiaro/chipseq (AFTER FIX) |
|-----------|----------------|---------------------------|-------------------------------|
| **PREPARE_GENOME emit** | `bowtie2_index = ch_bowtie2_index` (tuple) | `bowtie2_index = ch_bowtie2_index.map{...}` (path) ❌ | `bowtie2_index = ch_bowtie2_index` (tuple) ✅ |
| **PREPARE_GENOME emit** | `fasta = ch_fasta` (path) | `fasta = ch_fasta` (path) ✅ | `fasta = ch_fasta` (path) ✅ |
| **Main workflow** | `ch_fasta.map { [ [:], it ] }` ✅ | `PREPARE_GENOME.out.fasta` (no conversion) ❌ | `PREPARE_GENOME.out.fasta.map{...}` ✅ |
| **FASTQ_ALIGN_BOWTIE2** | `ch_index` expects tuple ✅ | `ch_index` expects path ❌ | `ch_index` expects tuple ✅ |
| **FASTQ_ALIGN_BOWTIE2** | `ch_fasta` expects tuple ✅ | `ch_fasta` expects path ❌ | `ch_fasta` expects tuple ✅ |

## Testing & Validation
- ✅ Nextflow lint passed with no syntax errors on modified files
- ✅ Channel structure matches nf-core/chipseq exactly
- ✅ All inputs to BOWTIE2_ALIGN are tuples as required
- ✅ Compared line-by-line with nf-core/chipseq repository

## Files Modified
1. **`subworkflows/local/prepare_genome.nf`** (line 151)
   - Reverted to emit tuple instead of extracting path
   
2. **`workflows/chipseq.nf`** (lines 222-233)
   - Added `.map { [ [:], it ] }` to convert `ch_fasta` to tuple
   
3. **`subworkflows/nf-core/fastq_align_bowtie2.nf`** (lines 11, 14)
   - Updated documentation to reflect tuple inputs

## Key Insights

### Why the Original Error Occurred
The `BOWTIE2_ALIGN` process uses Groovy's tuple destructuring:
```groovy
input:
tuple val(meta), path(reads)
tuple val(meta2), path(index)
tuple val(meta3), path(fasta)  // ← If this is NOT a tuple, meta3 becomes null!
```

When a **simple path** was passed instead of **tuple**, Nextflow couldn't destructure it properly:
- Expected: `[meta3, fasta_path]` → `meta3 = [:], fasta = path`
- Received: `fasta_path` → `meta3 = null, fasta = ???`

### The Critical Lesson
**In Nextflow DSL2**: When a process expects `tuple val(meta), path(file)`, you **MUST** provide a tuple, even if meta is empty `[:]`. A simple path alone will cause null meta errors!

## References
- Original repository: https://github.com/nf-core/chipseq (v2.0.0)
- Fork repository: https://github.com/pdichiaro/chipseq
- Error location: `modules/nf-core/modules/bowtie2/align/main.nf:31`
- BOWTIE2_ALIGN definition: `modules/nf-core/modules/bowtie2/align/main.nf:11-15`
