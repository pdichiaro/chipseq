#!/usr/bin/env nextflow

/*
 * Test script to verify ch_consensus_annotation conditional logic
 */

params.skip_peak_annotation = false

process MOCK_HOMER {
    output:
    tuple val("mock_meta"), path("mock_annotation.txt"), emit: txt
    
    script:
    """
    echo "Mock HOMER annotation" > mock_annotation.txt
    """
}

workflow {
    // Simulate HOMER process
    MOCK_HOMER()
    
    // Test the conditional logic from chipseq.nf
    def ch_consensus_annotation = !params.skip_peak_annotation 
        ? MOCK_HOMER.out.txt
            .map { meta, txt -> txt }
            .first()
        : channel.empty()
    
    // Verify the channel content
    ch_consensus_annotation.view { file -> 
        println "✅ SUCCESS: ch_consensus_annotation contains: ${file}"
        println "   skip_peak_annotation = ${params.skip_peak_annotation}"
    }
    
    println "\n=== Test Configuration ==="
    println "skip_peak_annotation: ${params.skip_peak_annotation}"
    println "Expected behavior: ${params.skip_peak_annotation ? 'Channel.empty()' : 'HOMER annotation file'}"
    println "========================\n"
}
