/*
 * Plot peak intersections across CONDITIONS (not individual replicates)
 * This creates an UpSet plot showing overlaps between condition-level consensus peaks
 * Only runs if there are >= 2 conditions for an antibody
 */
process PLOT_CONDITION_INTERSECT {
    tag "$antibody"
    label 'process_medium'

    conda (params.enable_conda ? "conda-forge::biopython conda-forge::r-optparse=1.7.1 conda-forge::r-upsetr=1.4.0 bioconda::bedtools=2.30.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-2f48cc59b03027e31ead6d383fe1b8057785dd24:5d182f583f4696f4c4d9f3be93052811b383341f-0':
        'quay.io/biocontainers/mulled-v2-2f48cc59b03027e31ead6d383fe1b8057785dd24:5d182f583f4696f4c4d9f3be93052811b383341f-0' }"

    input:
    tuple val(antibody), val(condition_ids), path(peaks)

    output:
    tuple val(antibody), path("*.conditions.intersect.txt"), emit: intersect_txt
    tuple val(antibody), path("*.conditions.intersect.plot.pdf"), emit: pdf
    path "versions.yml", emit: versions

    when:
    (task.ext.when == null || task.ext.when) && condition_ids.size() >= 2

    script:
    def prefix = task.ext.prefix ?: "${antibody}"
    def peak_type = params.narrow_peak ? 'narrowPeak' : 'broadPeak'
    def mergecols = params.narrow_peak ? (2..10).join(',') : (2..9).join(',')
    def collapsecols = params.narrow_peak ? (['collapse']*9).join(',') : (['collapse']*8).join(',')
    def expandparam = params.narrow_peak ? '--is_narrow_peak' : ''
    
    // Create clean condition names for labeling (remove _peaks.narrowPeak suffix)
    def condition_names = condition_ids.collect { it.replaceAll("_peaks\\.${peak_type}\$", "") }.join(',')
    
    """
    # Sort and merge all condition consensus peaks
    sort -T '.' -k1,1 -k2,2n ${peaks.collect{it.toString()}.sort().join(' ')} \\
        | mergeBed -c $mergecols -o $collapsecols > ${prefix}.merged.txt
  
    # Create boolean matrix to show which CONDITIONS have peaks in each region
    macs2_merged_expand.py \\
        ${prefix}.merged.txt \\
        ${condition_names} \\
        ${prefix}.boolean.txt \\
        --min_replicates 1 \\
        $expandparam

    # Generate UpSet plot showing peak overlaps between CONDITIONS
    if [ -s ${prefix}.boolean.intersect.txt ]; then
        plot_peak_intersect.r \\
            -i ${prefix}.boolean.intersect.txt \\
            -o ${prefix}.conditions.intersect.plot.pdf
    else
        echo "No intersect data available for conditions" > ${prefix}.conditions.intersect.plot.pdf
    fi

    # Keep the intersect file for output
    cp ${prefix}.boolean.intersect.txt ${prefix}.conditions.intersect.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
        bedtools: \$(bedtools --version | sed 's/bedtools v//')
    END_VERSIONS
    """
}
