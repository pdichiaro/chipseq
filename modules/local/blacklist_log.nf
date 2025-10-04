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
    tuple val(meta), path(bam), path(bai)
    path blacklist

    output:
    path "*.blacklist.log", emit: log
    path "versions.yml"   , emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Calculate total reads
    TOTAL_READS=\$(samtools view -c ${bam})
    
    # Calculate reads in blacklist regions
    READS_IN_BL=\$(bedtools intersect -a ${bam} -b ${blacklist} -u | samtools view -c -)
    
    # Calculate reads after blacklist removal
    READS_AFTER_BL=\$((TOTAL_READS - READS_IN_BL))
    
    # Calculate percentages
    PERCENT_REMOVED=\$(awk "BEGIN {printf \\"%.2f\\", (\$READS_IN_BL / \$TOTAL_READS) * 100}")
    PERCENT_RETAINED=\$(awk "BEGIN {printf \\"%.2f\\", (\$READS_AFTER_BL / \$TOTAL_READS) * 100}")
    
    # Number of blacklist regions
    NUM_BL_REGIONS=\$(wc -l < ${blacklist})
    
    # Generate log
    cat > ${prefix}.blacklist.log <<EOF
========================================================================
BLACKLIST FILTERING LOG - Sample: ${meta.id}
========================================================================

Date: \$(date '+%Y-%m-%d %H:%M:%S')
Input BAM: ${bam}
Blacklist: ${blacklist}

------------------------------------------------------------------------
STATISTICS
------------------------------------------------------------------------

Total reads in input BAM:           \$(printf "%15s" "\$(printf "%'d" \$TOTAL_READS)")

Reads IN blacklist regions:         \$(printf "%15s" "\$(printf "%'d" \$READS_IN_BL)")  (\${PERCENT_REMOVED}%)
Reads OUTSIDE blacklist (retained): \$(printf "%15s" "\$(printf "%'d" \$READS_AFTER_BL)")  (\${PERCENT_RETAINED}%)

Number of blacklist regions:        \$(printf "%15s" "\$(printf "%'d" \$NUM_BL_REGIONS)")

------------------------------------------------------------------------
SUMMARY
------------------------------------------------------------------------

Reads removed:     \$(printf "%'d" \$READS_IN_BL) (\${PERCENT_REMOVED}%)
Reads retained:    \$(printf "%'d" \$READS_AFTER_BL) (\${PERCENT_RETAINED}%)

========================================================================
EOF

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
        bedtools: \$(bedtools --version | sed -e "s/bedtools v//g")
    END_VERSIONS
    """
}
