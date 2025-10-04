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

    path ('*')  // DESeq2 PCA plots
    path ('*')  // DESeq2 clustering/distance plots

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
    # Stage DESeq2 QC files in ordered directory to preserve numeric order
    # Sort by existing filename (already has 01_, 02_, etc. prefixes)
    mkdir -p deseq2_qc_staged
    
    # Sort files alphabetically and copy to staging directory
    for file in \$(ls *_mqc.txt 2>/dev/null | sort); do
        if [ -f "\$file" ]; then
            cp "\$file" "deseq2_qc_staged/\$file"
        fi
    done
    
    # Move staged files back to current directory (overwrites originals in sorted order)
    if [ -d deseq2_qc_staged ] && [ "\$(ls -A deseq2_qc_staged)" ]; then
        mv deseq2_qc_staged/* .
        rmdir deseq2_qc_staged
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
