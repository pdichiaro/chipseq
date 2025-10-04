/*
 * Generate a simple log showing how many reads are removed by blacklist filtering
 */
process BLACKLIST_LOG {
    tag "$meta.id"
    label 'process_low'
    publishDir path: { "${params.outdir}/${params.aligner}/mergedLibrary/blacklist_metrics" }, mode: params.publish_dir_mode

    conda (params.enable_conda ? "bioconda::bedtools=2.30.0 bioconda::samtools=1.15.1" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-8186960447c5cb2faa697666dc1e6d919ad23f3e:3127fcae6b6bdaf8181e21a26ae61231030a9fcb-0':
        'quay.io/biocontainers/mulled-v2-8186960447c5cb2faa697666dc1e6d919ad23f3e:3127fcae6b6bdaf8181e21a26ae61231030a9fcb-0' }"

    input:
    tuple val(meta), path(bam_before), path(bai_before)
    tuple val(meta2), path(bam_after), path(bai_after)
    path blacklist

    output:
    path "*.blacklist.log", emit: log
    path "versions.yml"   , emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Calculate total reads BEFORE filtering
    TOTAL_READS=\$(samtools view -c ${bam_before})
    
    # Calculate reads in blacklist regions (from BEFORE BAM)
    READS_IN_BL=\$(bedtools intersect -a ${bam_before} -b ${blacklist} -u | samtools view -c -)
    
    # Calculate ACTUAL reads in the AFTER BAM (the real filtered count)
    READS_AFTER_BL=\$(samtools view -c ${bam_after})
    
    # Calculate percentages
    PERCENT_REMOVED=\$(awk "BEGIN {printf \\"%.2f\\", (\$READS_IN_BL / \$TOTAL_READS) * 100}")
    PERCENT_RETAINED=\$(awk "BEGIN {printf \\"%.2f\\", (\$READS_AFTER_BL / \$TOTAL_READS) * 100}")
    
    # Number of blacklist regions
    NUM_BL_REGIONS=\$(wc -l < ${blacklist})
    
    # Calculate expected vs actual difference
    EXPECTED_AFTER_BL=\$((TOTAL_READS - READS_IN_BL))
    DIFF=\$((READS_AFTER_BL - EXPECTED_AFTER_BL))
    
    # Generate log
    cat > ${prefix}.blacklist.log <<EOF
========================================================================
BLACKLIST FILTERING LOG - Sample: ${meta.id}
========================================================================

Date: \$(date '+%Y-%m-%d %H:%M:%S')
Input BAM (before): ${bam_before}
Output BAM (after): ${bam_after}
Blacklist: ${blacklist}

------------------------------------------------------------------------
STATISTICS
------------------------------------------------------------------------

Total reads in input BAM:                \$(printf "%15s" "\$(printf "%'d" \$TOTAL_READS)")

Reads IN blacklist regions:              \$(printf "%15s" "\$(printf "%'d" \$READS_IN_BL)")  (\${PERCENT_REMOVED}%)
Reads ACTUALLY retained (from output):   \$(printf "%15s" "\$(printf "%'d" \$READS_AFTER_BL)")  (\${PERCENT_RETAINED}%)

Expected reads after filtering:          \$(printf "%15s" "\$(printf "%'d" \$EXPECTED_AFTER_BL)")
Actual reads in filtered BAM:            \$(printf "%15s" "\$(printf "%'d" \$READS_AFTER_BL)")
Difference (actual - expected):          \$(printf "%15s" "\$(printf "%'d" \$DIFF)")

Number of blacklist regions:             \$(printf "%15s" "\$(printf "%'d" \$NUM_BL_REGIONS)")

------------------------------------------------------------------------
SUMMARY
------------------------------------------------------------------------

Reads removed by blacklist:     \$(printf "%'d" \$READS_IN_BL) (\${PERCENT_REMOVED}%)
Reads in final filtered BAM:    \$(printf "%'d" \$READS_AFTER_BL) (\${PERCENT_RETAINED}%)

$(if [ \$DIFF -ne 0 ]; then
    echo "WARNING: Difference detected between expected and actual filtered reads!"
    echo "         This may indicate additional filtering steps (e.g., quality, flags)"
fi)

========================================================================
EOF

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
        bedtools: \$(bedtools --version | sed -e "s/bedtools v//g")
    END_VERSIONS
    """
}
