# Bowtie2 Alignment Parameters Verification Report

## Investigation Date
$(date)

## Repository
- **Source**: pdichiaro/chipseq (GitHub, main branch)
- **Key Files Examined**:
  - `chipseq/conf/modules.config` (lines 106-120)
  - `chipseq/modules/nf-core/modules/bowtie2/align/main.nf`
  - `chipseq/nextflow.config` (line 56)

---

## Parameter Analysis

### 1. **`--bowtie2_mode` Parameter**

**Status**: ❌ **DOES NOT EXIST** as a user-configurable parameter

**Findings**:
- No parameter named `bowtie2_mode` found in `nextflow.config` or any configuration files
- The alignment mode is **hardcoded** in `conf/modules.config`:
  ```groovy
  ext.args = params.keep_multi_map ? 
      '--very-sensitive --end-to-end --reorder -k 100' : 
      '--very-sensitive --end-to-end --reorder'
  ```
- **Hardcoded value**: `--end-to-end` (NOT `--local`)
- Users **cannot** change this via pipeline parameters

---

### 2. **`--bowtie2_sensitivity` Parameter**

**Status**: ❌ **DOES NOT EXIST** as a user-configurable parameter

**Findings**:
- No parameter named `bowtie2_sensitivity` found in configuration files
- The sensitivity preset is **hardcoded** in `conf/modules.config`:
  ```groovy
  ext.args = '--very-sensitive --end-to-end --reorder ...'
  ```
- **Hardcoded value**: `--very-sensitive` (combined with `--end-to-end`)
- **Full preset used**: `--very-sensitive` (NOT `--very-sensitive-local`)
- Users **cannot** change this via pipeline parameters

---

### 3. **`--insert_size` Parameter**

**Status**: ✅ **EXISTS** as a user-configurable parameter

**Findings**:
- **Location**: `nextflow.config`, line 56
- **Default value**: `500` (bp)
- **Usage**: Applied in `modules/local/bam_filter.nf` for fragment size filtering
- **Purpose**: Maximum insert size threshold for quality filtering paired-end reads
- **Code excerpt from bam_filter.nf**:
  ```groovy
  def max_frag = params.insert_size ? params.insert_size.toInteger() : 500
  # awk: Filter pairs with insert size <= max_frag (default: params.insert_size = 500bp)
  ```
- Users **can** override this via `--insert_size` command-line parameter

---

## Hypothesis Verification

### Original Hypothesis
> "The pipeline always uses `--very-sensitive` for Bowtie2 alignment."

### ✅ **CONFIRMED**

**Evidence**:
1. The configuration file `conf/modules.config` explicitly sets:
   ```groovy
   ext.args = '--very-sensitive --end-to-end --reorder ...'
   ```

2. This is the **only** bowtie2 sensitivity configuration in the entire pipeline

3. The `--very-sensitive` flag is **hardcoded** and not user-configurable

4. Both `keep_multi_map` conditions use the same sensitivity preset:
   - `keep_multi_map = false`: `'--very-sensitive --end-to-end --reorder'`
   - `keep_multi_map = true`: `'--very-sensitive --end-to-end --reorder -k 100'`

---

## Additional Findings

### Paired-End Specific Handling

**From `modules/nf-core/modules/bowtie2/align/main.nf` (line 38-39)**:
```groovy
if (!meta.single_end) {
    pe_args = "-X 1000"  // Max fragment size for PE reads
}
```

**Key Point**: Bowtie2 has a **separate** maximum fragment size parameter (`-X 1000`) that is **hardcoded** in the process module, independent of the `params.insert_size` parameter.

- **`-X 1000`**: Bowtie2's internal maximum fragment length for paired-end alignment (1000 bp)
- **`params.insert_size` (500 bp)**: Post-alignment filtering threshold used in `bam_filter.nf`

These serve **different purposes**:
1. `-X 1000`: Bowtie2 won't consider fragment pairs > 1000 bp during alignment
2. `--insert_size 500`: Downstream BAM filtering removes aligned pairs > 500 bp

---

## Complete Bowtie2 Command Reconstruction

### For Paired-End Data (keep_multi_map = false)
```bash
bowtie2 \
    -x $INDEX \
    -1 reads_1.fq.gz \
    -2 reads_2.fq.gz \
    --threads $task.cpus \
    -X 1000 \
    --very-sensitive \
    --end-to-end \
    --reorder \
    | samtools view -F4 -bhS --threads $task.cpus -o output.bam -
```

### For Paired-End Data (keep_multi_map = true)
```bash
bowtie2 \
    -x $INDEX \
    -1 reads_1.fq.gz \
    -2 reads_2.fq.gz \
    --threads $task.cpus \
    -X 1000 \
    --very-sensitive \
    --end-to-end \
    --reorder \
    -k 100 \
    | samtools view -F4 -bhS --threads $task.cpus -o output.bam -
```

---

## Summary Table

| Parameter | Exists? | Default Value | User Configurable? | Actual Usage |
|-----------|---------|---------------|-------------------|--------------|
| `--bowtie2_mode` | ❌ No | N/A | ❌ No | Hardcoded: `--end-to-end` |
| `--bowtie2_sensitivity` | ❌ No | N/A | ❌ No | Hardcoded: `--very-sensitive` |
| `--insert_size` | ✅ Yes | 500 bp | ✅ Yes | Post-alignment filtering in `bam_filter.nf` |

---

## Recommendations

1. **Documentation Accuracy**: If pipeline documentation mentions `--bowtie2_mode` or `--bowtie2_sensitivity` parameters, these references are **incorrect** and should be removed or clarified that these are hardcoded values.

2. **Parameter Naming Clarity**: The `--insert_size` parameter should be clearly documented as a **post-alignment filtering threshold**, not a Bowtie2 alignment parameter.

3. **Potential Enhancement**: Consider making bowtie2 sensitivity and mode configurable via pipeline parameters if users need flexibility (e.g., for long-read ChIP-seq or other specialized applications).

4. **Fragment Size Clarification**: Document the distinction between:
   - Bowtie2's `-X 1000` (alignment-time maximum)
   - `params.insert_size` (post-alignment filtering threshold)

---

## Conclusion

**Your hypothesis is CORRECT**: The chipseq pipeline **always** uses `--very-sensitive` for Bowtie2 alignment, as it is hardcoded in the configuration and not user-configurable. The parameters `--bowtie2_mode` and `--bowtie2_sensitivity` do not exist as pipeline parameters, while `--insert_size` does exist but serves a different purpose (post-alignment filtering).
