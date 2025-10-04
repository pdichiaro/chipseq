process DESEQ2_TRANSFORM {
    label 'process_single'
    tag "$deseq2_file"

    conda "conda-forge::sed=4.7"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    path deseq2_file
    path 'headers/*'  // All header files in a directory

    output:
    path "*_mqc.tsv", optional: true, emit: multiqc_files
    path "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def file_name = deseq2_file.getName()
    def base_name = file_name.replaceAll(/\.txt$/, '')
    def output_name = "${base_name}_mqc.tsv"
    """
    # Detect plot type and gene set from filename
    # Patterns: featureCounts.deseq2.<geneset>.<plottype>.txt
    GENE_SET=""
    HEADER_FILE=""
    
    # Determine gene set
    if [[ "${file_name}" == *.all_genes.* ]]; then
        GENE_SET="all_genes"
    elif [[ "${file_name}" == *.invariant_genes.* ]]; then
        GENE_SET="invariant_genes"
    fi
    
    # Determine plot type and select appropriate header from headers/ directory
    # Check top PCA first (more specific pattern)
    if [[ "${file_name}" == *".pca.top"*".vals.txt" ]]; then
        HEADER_FILE="headers/deseq2_\${GENE_SET}_pca_top_header.txt"
    elif [[ "${file_name}" == *".pca.vals.txt" ]]; then
        HEADER_FILE="headers/deseq2_\${GENE_SET}_pca_all_header.txt"
    elif [[ "${file_name}" == *".sample.dists."* ]]; then
        HEADER_FILE="headers/deseq2_\${GENE_SET}_sample_dist_header.txt"
    elif [[ "${file_name}" == *".read.distribution.normalized."* ]]; then
        HEADER_FILE="headers/deseq2_\${GENE_SET}_read_dist_header.txt"
    fi
    
    # Create output file with header
    if [[ -n "\${HEADER_FILE}" && -f "\${HEADER_FILE}" ]]; then
        echo "Processing ${file_name}"
        echo "Using header: \${HEADER_FILE}"
        echo "Creating: ${output_name}"
        # Remove leading # from header lines, then concatenate with data
        sed 's/^#//' "\${HEADER_FILE}" > temp_header.txt
        cat temp_header.txt ${deseq2_file} > "${output_name}"
    else
        echo "Warning: No specific header found for ${file_name}"
        echo "Available headers:"
        ls -la headers/
        echo "Copying data without header to ${output_name}"
        cp ${deseq2_file} "${output_name}"
    fi

    cat <<-END_VERSIONS > versions.yml
\t"${task.process}":
\t    bash: \$(bash --version | head -n1 | awk '{print \$4}')
\tEND_VERSIONS
    """

    stub:
    """
    touch stub_file.txt

    cat <<END_VERSIONS > versions.yml
"${task.process}":
    bash: \$(bash --version | head -n1 | awk '{print \$4}')
END_VERSIONS
    """
}
