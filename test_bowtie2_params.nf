#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Test parameters
params.keep_multi_map = false
params.save_unaligned = false

process TEST_BOWTIE2_PARAMS {
    tag "$meta.id"
    
    input:
    tuple val(meta), path(reads)
    
    script:
    // Simulate the config from modules.config
    def args = params.keep_multi_map ? 
        '--very-sensitive --end-to-end --reorder -k 100' : 
        '--very-sensitive --end-to-end --reorder'
    def args2 = '-F4 -bhS'
    def prefix = meta.id
    def save_unaligned = params.save_unaligned

    def unaligned = ""
    def reads_args = ""
    def pe_args = ""
    if (meta.single_end) {
        unaligned = save_unaligned ? "--un-gz ${prefix}.unmapped.fastq.gz" : ""
        reads_args = "-U ${reads}"
        pe_args = ""
    } else {
        unaligned = save_unaligned ? "--un-conc-gz ${prefix}.unmapped.fastq.gz" : ""
        reads_args = "-1 ${reads[0]} -2 ${reads[1]}"
        pe_args = "-X 1000"
    }

    """
    echo "========================================="
    echo "BOWTIE2 PARAMETERS TEST"
    echo "========================================="
    echo "Sample: ${prefix}"
    echo "Single-end: ${meta.single_end}"
    echo ""
    echo "reads_args: ${reads_args}"
    echo "threads: ${task.cpus}"
    echo "unaligned: ${unaligned}"
    echo "pe_args: ${pe_args}"
    echo "args (ext.args): ${args}"
    echo "args2 (ext.args2): ${args2}"
    echo ""
    echo "FULL BOWTIE2 COMMAND WOULD BE:"
    echo "bowtie2 -x INDEX ${reads_args} --threads ${task.cpus} ${unaligned} ${pe_args} ${args}"
    echo "========================================="
    """
}

workflow {
    // Create test data
    Channel.of(
        [
            [id: 'sample_SE', single_end: true],
            file('dummy_R1.fq.gz')
        ],
        [
            [id: 'sample_PE', single_end: false],
            [file('dummy_R1.fq.gz'), file('dummy_R2.fq.gz')]
        ]
    )
    | TEST_BOWTIE2_PARAMS
}
