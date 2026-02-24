# MultiQC Section Header Path Fix

## Issue
The `featureCounts_deseq2_section_header_mqc.txt` file was being staged in the `deseq2/` directory instead of the `multiqc/` directory when passed to MultiQC.

## Root Cause
In `/home/user/chipseq/modules/local/multiqc.nf`, the MultiQC process had two consecutive input paths both set to `path ('deseq2/*')`:
- First `path ('deseq2/*')` for DESEQ2_SECTION_HEADER.out.section_header
- Second `path ('deseq2/*')` for DESEQ2_TRANSFORM.out.multiqc_files

This caused the section header file to be placed in the same directory as the DESeq2 outputs.

## Solution
Modified the first input path from `path ('deseq2/*')` to `path ('multiqc/*')` to properly stage the section header file:

```groovy
// Before:
path ('deseq2/*')  # DESEQ2_SECTION_HEADER.out.section_header
path ('deseq2/*')  # DESEQ2_TRANSFORM.out.multiqc_files

// After:
path ('multiqc/*')  # DESEQ2_SECTION_HEADER.out.section_header
path ('deseq2/*')   # DESEQ2_TRANSFORM.out.multiqc_files
```

## Files Modified
- `/home/user/chipseq/modules/local/multiqc.nf` (lines 45-46)

## Verification
- Syntax check: ✅ Passed `nextflow lint modules/local/multiqc.nf`
- Input order matches workflow call order in `workflows/chipseq.nf` (lines 967-968)

## Expected Behavior
When the workflow runs:
1. DESEQ2_SECTION_HEADER generates `featureCounts_deseq2_section_header_mqc.txt`
2. The file is staged in the MultiQC work directory as `multiqc/featureCounts_deseq2_section_header_mqc.txt`
3. DESEQ2_TRANSFORM outputs are staged in `deseq2/` directory
4. MultiQC can now find the section header in the expected location

## Notes
- This fix aligns with the intended directory structure where section headers belong in `multiqc/` rather than module-specific directories
- The `publishDir` for DESEQ2_SECTION_HEADER remains disabled (enabled: false) as the file is only needed by MultiQC, not for final output
- This is consistent with how other section header files are handled in the pipeline
