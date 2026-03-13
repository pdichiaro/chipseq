# Migration Summary: Closure Removal from modules.config

## 🎯 Objective
Remove closure from `ext.args` in `modules.config` for BOWTIE2_ALIGN to prevent metadata access issues, while maintaining all conditional logic.

## 📋 Changes Made

### BEFORE (Commit f67d535) - modules.config
```groovy
withName: 'CHIPSEQ:FASTQ_ALIGN_BOWTIE2:BOWTIE2_ALIGN' {
    ext.args = { meta ->
        def base_args = params.keep_multi_map ? 
            '--very-sensitive --end-to-end --reorder -k 100' : 
            '--very-sensitive --end-to-end --reorder'
        def pe_args = meta.single_end ? '' : ' -X 1000'
        return base_args + pe_args
    }
    // ^ CLOSURE accessing meta - caused null errors
}
```

### AFTER (Commit 5bb02d0 + 89099fa) - modules.config
```groovy
withName: 'CHIPSEQ:FASTQ_ALIGN_BOWTIE2:BOWTIE2_ALIGN' {
    // NOTE: PE-specific args (-X 1000) are now handled inside the process script
    //       to avoid closure evaluation issues with meta object
    ext.args = params.keep_multi_map ? 
        '--very-sensitive --end-to-end --reorder -k 100' : 
        '--very-sensitive --end-to-end --reorder'
    // ^ TERNARY EXPRESSION (not closure) - safe to use
}
```

### AFTER - bowtie2/align/main.nf (Process Script)
```groovy
script:
def args = task.ext.args ?: ""
def args2 = task.ext.args2 ?: ""
def prefix = task.ext.prefix ?: "${meta.id}"

def unaligned = ""
def reads_args = ""
def pe_args = ""
if (meta.single_end) {
    unaligned = save_unaligned ? "--un-gz ${prefix}.unmapped.fastq.gz" : ""
    reads_args = "-U ${reads}"
    pe_args = ""
} else {
    unaligned = save_unaligned ? "--un-conc-gz ${prefix}.unmapped.fastq.gz" : ""
    reads_args = "-1 ${reads[0]} -2 ${reads[1]}"
    pe_args = "-X 1000"  // ← MOVED HERE from config
}

"""
bowtie2 \\
    -x \$INDEX \\
    $reads_args \\
    --threads $task.cpus \\
    $unaligned \\
    $pe_args \\        ← Applied here
    $args \\
    2> >(tee ${prefix}.bowtie2.log >&2) \\
    | samtools ...
"""
```

## 🔑 Key Technical Points

### 1. Why Closures Failed
```groovy
ext.args = { meta -> ... }
         //  ^^^^
         //  This creates a closure that's evaluated LATER
         //  At evaluation time, 'meta' may not be in scope → null error
```

### 2. Why Ternary Expressions Work
```groovy
ext.args = params.keep_multi_map ? '...' : '...'
         //  ^^^^^^^^^^^^^^^^^^^
         //  Evaluated ONCE at config parsing time
         //  Result is a STRING, not a closure
```

### 3. Where to Put Conditional Logic

| Logic Type | Location | Reason |
|------------|----------|--------|
| **Global parameter-based** | `modules.config` (ternary) | ✅ Safe - no runtime evaluation |
| **Meta-dependent (SE/PE)** | Process script | ✅ Safe - meta is in scope |
| **Sample-specific** | Process script | ✅ Only place with sample context |

## ✅ Verification Checklist

- [x] Closure removed from `ext.args`
- [x] PE-specific `-X 1000` moved to process script
- [x] Conditional logic based on `meta.single_end` works correctly
- [x] `params.keep_multi_map` ternary expression in config (safe)
- [x] All metadata flows correctly through channels
- [x] Nextflow lint passes with no errors

## 📊 Impact

**Before:** Meta object was null due to closure evaluation scope issues  
**After:** Meta flows correctly through all processes

**Files Modified:**
1. `conf/modules.config` - Removed closure, kept ternary expression
2. `modules/nf-core/modules/bowtie2/align/main.nf` - Added PE/SE logic
3. (No channel structure changes needed - original design was correct)

## 🎓 Best Practices Learned

1. **Use closures in config ONLY when necessary**
   - Accessing `meta` in `ext.args` closure is risky
   - Prefer static strings or simple ternary expressions

2. **Move sample-specific logic to process scripts**
   - Process scripts have guaranteed access to `meta`
   - Cleaner separation of concerns

3. **Ternary expressions are safe in config**
   ```groovy
   ext.args = condition ? 'value1' : 'value2'  // ✅ Safe
   ext.args = { meta -> ... }                  // ⚠️  Risky
   ```

4. **Configuration happens at different times**
   - Config file: Parsed ONCE before workflow starts
   - Process script: Evaluated FOR EACH task instance
   - Choose location based on when data is available

---

**Status:** ✅ **COMPLETE AND VERIFIED**  
**Commits:** 5bb02d0 (fix) + 89099fa (cleanup)  
**Date:** 2026-03-13
