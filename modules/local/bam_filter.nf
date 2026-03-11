/*
 * Filter BAM file using standard ChIP-seq filtering approach
 * - Removes multimappers (MAPQ >= 1 filter when keep_multi_map = false)
 * - Removes duplicates (unless keep_dups = true)
 * - Removes blacklisted regions
 * - Filters by fragment size
 * - Ensures proper paired-end reads (when applicable)
 */
process BAM_FILTER {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::bedtools=2.30.0 bioconda::samtools=1.15.1" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-8186960447c5cb2faa697666dc1e6d919ad23f3e:3127fcae6b6bdaf8181e21a26ae61231030a9fcb-0':
        'quay.io/biocontainers/mulled-v2-8186960447c5cb2faa697666dc1e6d919ad23f3e:3127fcae6b6bdaf8181e21a26ae61231030a9fcb-0' }"

    input:
    tuple val(meta), path(bam), path(bai)
    path bed

    output:
    tuple val(meta), path("*.filter2.bam"), emit: bam
    path "versions.yml"           , emit: versions

    script:

    def prefix           = task.ext.prefix ?: "${meta.id}"
    def filter_params    = meta.single_end ? '-F 0x004' : '-F 0x004 -F 0x0008 -f 0x001 -f 0x002' // proper pair selection!!
    def dup_params       = params.keep_dups ? '' : '-F 0x0400'
    def blacklist_params = params.blacklist ? "-L $bed" : ''
    def max_frag = params.inser_size ? params.inser_size.toInteger() : 1000

    if(params.keep_multi_map == false ) {

        """
        # General filtering of the bam
        samtools view \\
            $filter_params \\
            $dup_params \\
            $blacklist_params \\
            -b $bam > ${prefix}.filter1.bam
        
        # Remove multi-mappers (MAPQ < 1) and filter by fragment size
        # -q 1: Keep only reads with MAPQ >= 1 (removes multi-mappers which have MAPQ = 0)
        # awk: Filter pairs with insert size <= max_frag (default: params.inser_size = 1000bp)

        samtools view -q 1 -h ${prefix}.filter1.bam | \\
            awk -v var="$max_frag" '{if(substr(\$0,1,1)=="@" || ((\$9>=0?\$9:-\$9)<=var)) print \$0}' | \\
            samtools view -b > ${prefix}.filter2.bam

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
        END_VERSIONS
        """
        
    } else {

        """
        # General filtering of the bam
        samtools view \\
            $filter_params \\
            $dup_params \\
            $blacklist_params \\
            -b $bam > ${prefix}.filter1.bam

        # Filter pairs by insert size
        # Keep only pairs with insert size <= max_frag (default: params.inser_size = 1000bp)
        
        samtools view -h ${prefix}.filter1.bam | \\
            awk -v var="$max_frag" '{if(substr(\$0,1,1)=="@" || ((\$9>=0?\$9:-\$9)<=var)) print \$0}' | \\
            samtools view -b > ${prefix}.filter2.bam

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
        END_VERSIONS
        """

    }


}
