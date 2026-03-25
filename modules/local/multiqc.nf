process MULTIQC {
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::multiqc=1.23" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/multiqc:1.23--pyhdfd78af_0':
        'quay.io/biocontainers/multiqc:1.23--pyhdfd78af_0' }"

    input:
    path multiqc_config
    path mqc_custom_config
    path software_versions
    path workflow_summary

    path ('fastqc/*')
    path ('trimgalore/fastqc/*')
    path ('trimgalore/*')

    path ('alignment/bowtie2/*')

    path ('alignment/library/*')
    path ('alignment/library/*')
    path ('alignment/library/*')

    path ('alignment/mergedLibrary/unfiltered/*')
    path ('alignment/mergedLibrary/unfiltered/*')
    path ('alignment/mergedLibrary/unfiltered/*')
    path ('alignment/mergedLibrary/unfiltered/picard_metrics/*')

    path ('alignment/mergedLibrary/filtered/*')
    path ('alignment/mergedLibrary/filtered/*')
    path ('alignment/mergedLibrary/filtered/*')
    path ('alignment/mergedLibrary/filtered/picard_metrics/*')

    path ('deeptools/*')
    path ('deeptools/*')

    path ('phantompeakqualtools/*')
    path ('phantompeakqualtools/*')
    path ('phantompeakqualtools/*')
    path ('phantompeakqualtools/*')

    path ('macs2/peaks/*')
    path ('macs2/peaks/*')
    path ('macs2/annotation/*')
    path ('macs2/featurecounts/*')

    val deseq2_pca_files       // DESeq2 PCA plots - passed as list of files
    val deseq2_clustering_files // DESeq2 clustering/distance plots - passed as list of files  
    val deseq2_header_file      // DESeq2 section header - passed as single file

    output:
    path "*multiqc_report.html", emit: report
    path "*_data"              , emit: data
    path "*_plots"             , optional:true, emit: plots
    path "versions.yml"        , emit: versions

    script:
    def args          = task.ext.args ?: ''
    def custom_config = params.multiqc_config ? "--config $mqc_custom_config" : ''
    
    // Handle DESeq2 files - copy them to appropriate locations
    def copy_deseq2_pca = deseq2_pca_files ? 
        deseq2_pca_files.collect { "cp ${it} multiqc_data/" }.join('\n    ') : 
        ''
    def copy_deseq2_clustering = deseq2_clustering_files ? 
        deseq2_clustering_files.collect { "cp ${it} multiqc_data/" }.join('\n    ') : 
        ''
    def copy_deseq2_header = deseq2_header_file ? 
        "cp ${deseq2_header_file} ." : 
        ''
    
    """
    # Create multiqc_data directory for DESeq2 files
    mkdir -p multiqc_data
    
    # Copy DESeq2 files to appropriate locations
    ${copy_deseq2_pca}
    ${copy_deseq2_clustering}
    ${copy_deseq2_header}
    
    multiqc \\
        -f \\
        $args \\
        $custom_config \\
        .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$( multiqc --version | sed -e "s/multiqc, version //g" )
    END_VERSIONS
    """
}
