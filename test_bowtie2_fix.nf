#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

/*
 * Test script per verificare il fix del problema "Cannot get property 'single_end' on null object"
 * Questo script testa solo la parte critica: il passaggio di canali a BOWTIE2_ALIGN
 */

// Parametri di test
params.outdir = 'test_results'
params.fasta = 'test_data/test_genome.fa'

// Include dei moduli necessari
include { BOWTIE2_BUILD } from './modules/nf-core/modules/bowtie2/build/main'
include { BOWTIE2_ALIGN } from './modules/nf-core/modules/bowtie2/align/main'

workflow {
    
    // Simula il channel di input come nel workflow reale
    def ch_reads = Channel.of(
        [
            [ id: 'TEST_SAMPLE', single_end: false, is_input: false ],
            [ file('test_data/sample1_R1.fastq'), file('test_data/sample1_R2.fastq') ]
        ]
    )
    
    // Simula PREPARE_GENOME.out.fasta come queue channel
    def ch_fasta = Channel.fromPath(params.fasta)
    
    // Build dell'indice Bowtie2 (simula PREPARE_GENOME.out.bowtie2_index)
    def ch_fasta_for_build = ch_fasta.map { fasta -> [ [:], fasta ] }
    BOWTIE2_BUILD(ch_fasta_for_build)
    def ch_bowtie2_index = BOWTIE2_BUILD.out.index.map { meta, index -> index }
    
    // ===== PARTE CRITICA: Questo è il fix che abbiamo applicato =====
    // Usiamo .collect() per trasformare i queue channels in value channels
    // Senza .collect(), ch_bowtie2_index e ch_fasta causerebbero l'errore
    // "Cannot get property 'single_end' on null object"
    
    BOWTIE2_ALIGN(
        ch_reads,
        ch_bowtie2_index.collect(),  // ← FIX: .collect() trasforma in value channel
        ch_fasta.collect(),           // ← FIX: .collect() trasforma in value channel
        false,  // save_unaligned
        false   // sort_bam
    )
    
    // Verifica output
    BOWTIE2_ALIGN.out.bam.view { meta, bam -> 
        "✅ SUCCESS! BAM generato per ${meta.id}: ${bam}"
    }
    
    BOWTIE2_ALIGN.out.log.view { meta, log ->
        "✅ SUCCESS! Log generato per ${meta.id}: ${log}"
    }
}

workflow.onComplete {
    println "\n========================================="
    if (workflow.success) {
        println "✅ TEST COMPLETATO CON SUCCESSO!"
        println "   Il fix .collect() funziona correttamente."
        println "   Il meta object è stato passato correttamente a BOWTIE2_ALIGN."
        println "   Nessun errore 'Cannot get property single_end on null object'."
    } else {
        println "❌ TEST FALLITO"
        println "   Errore: ${workflow.errorMessage}"
    }
    println "=========================================\n"
}
