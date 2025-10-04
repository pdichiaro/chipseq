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

    path ('multiqc_data/*_mqc.txt')  // DESeq2 QC files from multiqc_data/

    output:
    path "*multiqc_report.html", emit: report
    path "*_data"              , emit: data
    path "*_plots"             , optional:true, emit: plots
    path "versions.yml"        , emit: versions

    script:
    def args           = task.ext.args ?: ''
    def default_config = "--config $multiqc_config"
    def custom_config  = mqc_custom_config ? "--config $mqc_custom_config" : ''
    
    """
    # DESeq2 files are in multiqc_data/ directory with numeric prefixes
    # MultiQC will automatically find them there
    # Debug: List DESeq2 files if they exist
    if [ -d multiqc_data ] && [ "\$(ls -A multiqc_data 2>/dev/null)" ]; then
        echo "=== DESeq2 MultiQC files found ==="
        ls -lh multiqc_data/*_mqc.txt 2>/dev/null || echo "No *_mqc.txt files in multiqc_data/"
    else
        echo "⚠️  Warning: No multiqc_data/ directory or it's empty"
    fi

    multiqc \\
        -f \\
        $args \\
        $default_config \\
        $custom_config \\
        .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$( multiqc --version | sed -e "s/multiqc, version //g" )
    END_VERSIONS
    """
}
