# Fix for DESeq2 VST Parameter Error

## Problem
When running the pipeline with `--deseq2_vst True`, the pipeline failed with:
```
Error in getopt(spec = spec, opt = args) : 
  flag "vst" requires an argument
```

## Root Cause
The R script `bin/normalize_deseq2_qc_all_genes.r` defines the `--vst` flag as a **logical** type:
```r
make_option(c("-v", "--vst"), type="logical", default=FALSE, ...)
```

In R's `optparse` package, logical flags require explicit values like `TRUE` or `FALSE`.

However, the Nextflow configuration in `conf/modules.config` was passing just `--vst` without a value:
```groovy
ext.args = { params.deseq2_vst ? '--vst' : '' }
```

## Solution
Updated both DESeq2 normalization processes in `conf/modules.config` to pass explicit values:

**Before:**
```groovy
ext.args = { params.deseq2_vst ? '--vst' : '' }
```

**After:**
```groovy
ext.args = { params.deseq2_vst ? '--vst TRUE' : '--vst FALSE' }
```

## Changes Made
1. `NORMALIZE_DESEQ2_QC_ALL_GENES` - Fixed `--vst` parameter passing
2. `NORMALIZE_DESEQ2_QC_INVARIANT_GENES` - Fixed `--vst` parameter passing

## Testing
Now when you run:
```bash
nextflow run pdichiaro/chipseq --deseq2_vst True
```

The R script will receive `--vst TRUE` (or `--vst FALSE` when the parameter is false/not set), which is the correct format for R's optparse logical flags.

## Files Modified
- `conf/modules.config` - Updated argument passing for both NORMALIZE_DESEQ2_QC_* processes
