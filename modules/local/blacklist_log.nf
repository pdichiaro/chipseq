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
    tuple val(meta), path(bam_before), path(bai_before), path(bam_after), path(bai_after)
    path blacklist

    output:
    path "*.blacklist.log", emit: log
    path "versions.yml"   , emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Count reads BEFORE blacklist filtering
    READS_BEFORE=\$(samtools view -c ${bam_before})
    
    # Count reads AFTER blacklist filtering
    READS_AFTER=\$(samtools view -c ${bam_after})
    
    # Calculate reads removed
    READS_REMOVED=\$((READS_BEFORE - READS_AFTER))
    
    # Calculate percentages
    PERCENT_REMOVED=\$(awk "BEGIN {printf \\"%.2f\\", (\$READS_REMOVED / \$READS_BEFORE) * 100}")
    PERCENT_RETAINED=\$(awk "BEGIN {printf \\"%.2f\\", (\$READS_AFTER / \$READS_BEFORE) * 100}")
    
    # Number of blacklist regions
    NUM_BL_REGIONS=\$(wc -l < ${blacklist})
    
    # Generate log
    cat > ${prefix}.blacklist.log <<EOF
========================================================================
BLACKLIST FILTERING LOG - Sample: ${meta.id}
========================================================================

Date: \$(date '+%Y-%m-%d %H:%M:%S')
Input BAM (before filtering):  ${bam_before}
Output BAM (after filtering):  ${bam_after}
Blacklist regions file:        ${blacklist}

------------------------------------------------------------------------
STATISTICS
------------------------------------------------------------------------

Reads BEFORE blacklist filtering:  \$(printf "%15s" "\$(printf "%'d" \$READS_BEFORE)")
Reads AFTER blacklist filtering:   \$(printf "%15s" "\$(printf "%'d" \$READS_AFTER)")
Reads REMOVED:                     \$(printf "%15s" "\$(printf "%'d" \$READS_REMOVED)")  (\${PERCENT_REMOVED}%)

Number of blacklist regions:       \$(printf "%15s" "\$(printf "%'d" \$NUM_BL_REGIONS)")

------------------------------------------------------------------------
SUMMARY
------------------------------------------------------------------------

Total reads removed:    \$(printf "%'d" \$READS_REMOVED) (\${PERCENT_REMOVED}%)
Total reads retained:   \$(printf "%'d" \$READS_AFTER) (\${PERCENT_RETAINED}%)

========================================================================
EOF

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
        bedtools: \$(bedtools --version | sed -e "s/bedtools v//g")
    END_VERSIONS
    """
}
