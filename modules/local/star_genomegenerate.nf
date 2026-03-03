process STAR_GENOMEGENERATE {
    tag "$fasta"
    label 'process_high'

    // Note: 2.7X indices incompatible with AWS iGenomes.
    // Updated to match pdichiaro/rnaseq version
    conda "bioconda::htslib=1.21 bioconda::samtools=1.21 bioconda::star=2.7.11b conda-forge::gawk=5.1.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/26/268b4c9c6cbf8fa6606c9b7fd4fafce18bf2c931d1a809a0ce51b105ec06c89d/data' :
        'community.wave.seqera.io/library/htslib_samtools_star_gawk:ae438e9a604351a4' }"

    input:
    path fasta
    path gtf

    output:
    path "star"        , emit: index
    path "versions.yml", emit: versions

    script:
    def args   = (task.ext.args ?: '').tokenize()
    def memory = task.memory ? "--limitGenomeGenerateRAM ${task.memory.toBytes() - 100000000}" : ''
    if (args.contains('--genomeSAindexNbases')) {
        """
        mkdir star
        STAR \\
            --runMode genomeGenerate \\
            --genomeDir star/ \\
            --genomeFastaFiles $fasta \\
            --runThreadN $task.cpus \\
            $memory \\
            ${args.join(' ')}
        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            star: \$(STAR --version | sed -e "s/STAR_//g")
        END_VERSIONS
        """
    } else {
        """
        samtools faidx $fasta
        NUM_BASES=`gawk '{sum = sum + \$2}END{if ((log(sum)/log(2))/2 - 1 > 14) {printf "%.0f", 14} else {printf "%.0f", (log(sum)/log(2))/2 - 1}}' ${fasta}.fai`
        mkdir star
        STAR \\
            --runMode genomeGenerate \\
            --genomeDir star/ \\
            --genomeFastaFiles $fasta \\
            --runThreadN $task.cpus \\
            --genomeSAindexNbases \$NUM_BASES \\
            $memory \\
            ${args.join(' ')}
        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            star: \$(STAR --version | sed -e "s/STAR_//g")
        END_VERSIONS
        """
    }
}
