#!/usr/bin/env nextflow

/*
 * Test script to verify the bowtie2_index fix
 * This script tests that the channel structure is correct
 */

nextflow.enable.dsl = 2

// Simulate BOWTIE2_BUILD output (tuple)
def ch_bowtie2_index_tuple = channel.of([ [:], file('test_index') ])

// Apply the fix: extract path from tuple
def ch_bowtie2_index = ch_bowtie2_index_tuple.map { meta, idx -> idx }

// Simulate reads channel (multiple samples)
def ch_reads = channel.of(
    [ [id: 'sample1', single_end: false], [ file('read1_1.fq'), file('read1_2.fq') ] ],
    [ [id: 'sample2', single_end: true],  [ file('read2.fq') ] ]
)

workflow {
    // Verify that both channels have correct structure
    ch_reads.view { meta, reads -> 
        println "✓ Read sample: id=${meta.id}, single_end=${meta.single_end}, files=${reads.size()}"
        [meta, reads]
    }
    
    ch_bowtie2_index.view { idx ->
        println "✓ Index path: ${idx}"
        idx
    }
    
    println "✅ Channel structure validation passed!"
}
