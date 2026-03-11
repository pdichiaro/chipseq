# Insert Size Configuration Changes

## Summary
Separated Bowtie2 alignment search limit from biological fragment size filtering.

## Changes Made

### 1. **params.insert_size default: 1000 → 500**
**File:** `nextflow.config`
- **Old:** `insert_size = 1000`
- **New:** `insert_size = 500`
- **Rationale:** More stringent default aligned with standard ChIP-seq best practices (removes fragments >500bp as potential chimeras/artifacts)

### 2. **Bowtie2 -X parameter: Dynamic → Fixed 1000**
**File:** `conf/modules.config`
- **Old:** `-X ${params.insert_size}` (was 1000)
- **New:** `-X 1000` (fixed)
- **Rationale:** Decouples alignment search limit from downstream filtering. Bowtie2 always searches permissively up to 1000bp, ensuring no valid pairs are missed during alignment.

### 3. **BAM_FILTER fallback default: 1000 → 500**
**File:** `modules/local/bam_filter.nf`
- **Old:** `def max_frag = params.insert_size ?: 1000`
- **New:** `def max_frag = params.insert_size ?: 500`
- **Rationale:** Consistent with new default in nextflow.config

### 4. **Updated documentation**
Enhanced comments explaining the two-stage filtering:
- Bowtie2 `-X 1000`: Permissive search (don't miss alignments)
- `params.insert_size = 500`: Stringent biological filtering (remove artifacts)

## Behavior

### Alignment Phase (Bowtie2)
```bash
bowtie2 -X 1000 ...  # Always searches for pairs up to 1000bp
```

### Filtering Phase (BAM_FILTER)
```bash
awk '{if(($9<=500 && $9>=-500)) print $0}'  # Keeps only fragments ≤500bp
```

## User Customization

Users can adjust `insert_size` based on their ChIP-seq type:

```bash
# Narrow peaks (TF)
nextflow run ... --insert_size 400

# Standard (default)
nextflow run ... --insert_size 500

# Broad marks
nextflow run ... --insert_size 600
```

Bowtie2 `-X 1000` remains fixed, ensuring the aligner always has a permissive search window.

## Benefits

1. ✅ **Prevents alignment loss**: Bowtie2 never misses valid pairs due to conservative search limits
2. ✅ **Better quality control**: Downstream filtering at 500bp removes typical ChIP-seq artifacts
3. ✅ **User flexibility**: `insert_size` can be tuned without affecting alignment behavior
4. ✅ **Aligned with mmchipseq**: Similar strategy to established pipelines

## Migration

Existing users with explicit `--insert_size 1000` in their commands:
- **No action needed** - parameter will still work as before
- **Recommendation**: Test with new default (500) to evaluate impact on your data

New users:
- Use default (500) for standard ChIP-seq
- Adjust based on MultiQC Picard insert size metrics if needed
