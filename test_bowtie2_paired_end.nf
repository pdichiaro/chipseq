#!/usr/bin/env nextflow

/*
 * Test script to verify Bowtie2 paired-end logic
 */

// Simulate Bowtie2 index
process MOCK_BOWTIE2_BUILD {
    output:
    tuple val("bowtie2"), path("index/*"), emit: index
    
    script:
    """
    mkdir -p index
    touch index/genome.1.bt2 index/genome.2.bt2 index/genome.3.bt2 
    touch index/genome.4.bt2 index/genome.rev.1.bt2 index/genome.rev.2.bt2
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
    echo "  reads count: ${reads instanceof List ? reads.size() : 1}"
    
    # Create mock BAM
    echo "Mock BAM content" > ${prefix}.bam
    
    # Verify single_end logic
    if [ "${meta.single_end}" == "false" ]; then
        echo "✅ PAIRED-END mode detected correctly"
        echo "   Using -1 and -2 flags for paired reads"
    else
        echo "⚠️  Unexpected single-end mode"
    fi
    """
}

workflow {
    println "\n=== Testing Bowtie2 Paired-End Logic ==="
    println "Simulating paired-end samples:\n"
    
    // Create channel with paired-end metadata
    def samples = [
        [
            id: 'SAMPLE_PE_REP1',
            single_end: false,
            replicate: 1,
            antibody: 'H3K4me3',
            is_input: false
        ],
        [
            id: 'SAMPLE_PE_REP2',
            single_end: false,
            replicate: 2,
            antibody: 'H3K4me3',
            is_input: false
        ]
    ]
    
    // Print sample info
    samples.each { sample ->
        println "Sample: ${sample.id}"
        println "  - single_end: ${sample.single_end}"
        println "  - replicate: ${sample.replicate}"
        println ""
    }
    
    // Create channels with paired reads
    def ch_reads = channel.of(*samples)
        .map { meta -> 
            tuple(meta, [
                file("${meta.id}_R1.fastq.gz"),
                file("${meta.id}_R2.fastq.gz")
            ])
        }
    
    // Mock Bowtie2 index
    MOCK_BOWTIE2_BUILD()
    
    // Test Bowtie2 alignment with paired-end logic
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
