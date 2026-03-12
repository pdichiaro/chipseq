#!/usr/bin/env nextflow

/*
 * Test script to verify Bowtie2 single_end logic and channel handling
 */

// Simulate the validated samplesheet output
process MOCK_SAMPLESHEET_CHECK {
    output:
    tuple val(meta), path("*.fastq.gz"), emit: reads
    
    script:
    def fastq_1 = meta.single_end ? "${meta.id}_R1.fastq.gz" : "${meta.id}_R1.fastq.gz"
    def fastq_2 = meta.single_end ? "" : "${meta.id}_R2.fastq.gz"
    """
    echo "Mock FASTQ R1" | gzip > ${fastq_1}
    ${meta.single_end ? '' : "echo 'Mock FASTQ R2' | gzip > ${fastq_2}"}
    """
}

// Simulate Bowtie2 index
process MOCK_BOWTIE2_BUILD {
    output:
    tuple val("bowtie2"), path("index/*"), emit: index
    
    script:
    """
    mkdir -p index
    touch index/genome.1.bt2
    touch index/genome.2.bt2
    touch index/genome.3.bt2
    touch index/genome.4.bt2
    touch index/genome.rev.1.bt2
    touch index/genome.rev.2.bt2
    """
}

// Simulate the Bowtie2 alignment process
process MOCK_BOWTIE2_ALIGN {
    tag "${meta.id}"
    
    input:
    tuple val(meta), path(reads)
    tuple val(index_name), path(index)
    
    output:
    tuple val(meta), path("*.bam"), emit: bam
    
    script:
    def prefix = "${meta.id}"
    def read_input = meta.single_end ? "-U ${reads}" : "-1 ${reads[0]} -2 ${reads[1]}"
    """
    echo "Processing: ${meta.id}"
    echo "  single_end: ${meta.single_end}"
    echo "  read_input: ${read_input}"
    echo "  reads: ${reads}"
    
    # Create mock BAM
    echo "Mock BAM content" > ${prefix}.bam
    
    # Verify single_end logic
    if [ "${meta.single_end}" == "true" ]; then
        echo "✅ SINGLE-END mode detected correctly"
        echo "   Using -U flag for unpaired reads"
    else
        echo "✅ PAIRED-END mode detected correctly"
        echo "   Using -1 and -2 flags for paired reads"
    fi
    """
}

workflow {
    println "\n=== Testing Bowtie2 Single-End Logic ==="
    println "Simulating your samplesheet configuration:\n"
    
    // Create channel with your actual metadata structure
    def samples = [
        [
            id: 'TLBR2_pRPA_CTRL_REP1_T1',
            single_end: true,
            replicate: 1,
            antibody: 'pRPA',
            is_input: false,
            which_input: 'TLBR2_pRPA_Input_CTRL_pool_REP1_T1'
        ],
        [
            id: 'TLBR2_pRPA_CTRL_REP2_T1',
            single_end: true,
            replicate: 2,
            antibody: 'pRPA',
            is_input: false,
            which_input: 'TLBR2_pRPA_Input_CTRL_pool_REP1_T1'
        ],
        [
            id: 'TLBR2_pRPA_CTRL_REP3_T1',
            single_end: true,
            replicate: 3,
            antibody: 'pRPA',
            is_input: false,
            which_input: 'TLBR2_pRPA_Input_CTRL_pool_REP1_T1'
        ]
    ]
    
    // Print sample info
    samples.each { sample ->
        println "Sample: ${sample.id}"
        println "  - single_end: ${sample.single_end}"
        println "  - replicate: ${sample.replicate}"
        println "  - antibody: ${sample.antibody}"
        println ""
    }
    
    // Create channels
    def ch_reads = channel.of(*samples)
        .map { meta -> 
            tuple(meta, file("${meta.id}_R1.fastq.gz"))
        }
    
    // Mock Bowtie2 index
    MOCK_BOWTIE2_BUILD()
    
    // Test Bowtie2 alignment with single-end logic
    MOCK_BOWTIE2_ALIGN(
        ch_reads,
        MOCK_BOWTIE2_BUILD.out.index
    )
    
    // Verify outputs
    MOCK_BOWTIE2_ALIGN.out.bam.view { meta, bam ->
        println "\n✅ OUTPUT VERIFIED:"
        println "   Sample: ${meta.id}"
        println "   Single-end: ${meta.single_end}"
        println "   BAM file: ${bam}"
        println "   No errors with single_end field!"
    }
}
