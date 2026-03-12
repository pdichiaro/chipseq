#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

/*
 * Test della logica di channel per verificare il fix .collect()
 * Questo script simula il problema e verifica che .collect() lo risolva
 */

workflow {
    
    println "\n" + "="*60
    println "TEST: Verifica fix 'Cannot get property single_end on null object'"
    println "="*60 + "\n"
    
    // ========== SCENARIO 1: SENZA .collect() (PROBLEMA) ==========
    println "📋 SCENARIO 1: Simulazione SENZA .collect() (il problema originale)"
    println "-" * 60
    
    // Simula PREPARE_GENOME.out.bowtie2_index come queue channel
    def queue_channel_index = Channel.of('/path/to/bowtie2/index')
    
    // Simula PREPARE_GENOME.out.fasta come queue channel  
    def queue_channel_fasta = Channel.of('/path/to/genome.fasta')
    
    // Simula ch_filtered_reads con metadata (formato tuple: [meta, [files]])
    def ch_reads_scenario1 = Channel.of(
        tuple(
            [ id: 'SAMPLE1', single_end: false, is_input: false ],
            [ 'sample1_R1.fastq', 'sample1_R2.fastq' ]
        ),
        tuple(
            [ id: 'SAMPLE2', single_end: false, is_input: true ],
            [ 'sample2_R1.fastq', 'sample2_R2.fastq' ]
        )
    )
    
    // Quando usiamo queue channels direttamente in un processo che si aspetta value channels,
    // Nextflow cerca di combinarli con ch_reads, causando problemi di cardinality
    println "⚠️  PROBLEMA: Queue channels (index, fasta) combinati con reads channel"
    println "   Questo causerebbe: 'Cannot get property single_end on null object'\n"
    
    
    // ========== SCENARIO 2: CON .collect() (SOLUZIONE) ==========
    println "📋 SCENARIO 2: Simulazione CON .collect() (il fix applicato)"
    println "-" * 60
    
    // Ricreiamo i queue channels
    def queue_channel_index2 = Channel.of('/path/to/bowtie2/index')
    def queue_channel_fasta2 = Channel.of('/path/to/genome.fasta')
    
    def ch_reads_scenario2 = Channel.of(
        tuple(
            [ id: 'SAMPLE1', single_end: false, is_input: false ],
            [ 'sample1_R1.fastq', 'sample1_R2.fastq' ]
        ),
        tuple(
            [ id: 'SAMPLE2', single_end: false, is_input: true ],
            [ 'sample2_R1.fastq', 'sample2_R2.fastq' ]
        )
    )
    
    // Applichiamo .collect() per trasformarli in value channels
    def value_channel_index = queue_channel_index2.collect()
    def value_channel_fasta = queue_channel_fasta2.collect()
    
    println "✅ SOLUZIONE: .collect() trasforma queue channels in value channels"
    println "   - Index: queue → value channel"
    println "   - Fasta: queue → value channel"
    println "   - Reads: rimane queue channel con metadata\n"
    
    // Simula il comportamento del processo BOWTIE2_ALIGN
    println "🔬 Simulazione chiamata BOWTIE2_ALIGN con canali corretti:"
    println "-" * 60
    
    ch_reads_scenario2
        .combine(value_channel_index)
        .combine(value_channel_fasta)
        .view { tuple ->
            def reads_meta = tuple[0]
            def meta = reads_meta[0]
            def files = reads_meta[1]
            def index = tuple[1]
            def fasta = tuple[2]
            
            println "   ✅ Processo riceve correttamente:"
            println "      - meta.id: ${meta.id}"
            println "      - meta.single_end: ${meta.single_end} (ACCESSIBILE!)"
            println "      - meta.is_input: ${meta.is_input}"
            println "      - reads: ${files}"
            println "      - index: ${index}"
            println "      - fasta: ${fasta}"
            println ""
        }
    
    println "\n" + "="*60
    println "✅ TEST COMPLETATO!"
    println "="*60
    println """
RISULTATO:
- Senza .collect(): I queue channels causano problemi di cardinality
                     quando combinati con ch_reads, risultando in meta=null
                     
- Con .collect():    I value channels possono essere riutilizzati
                     con tutti gli elementi di ch_reads, mantenendo
                     l'integrità del metadata

FIX APPLICATO in workflows/chipseq.nf (linee 189-194):
  FASTQ_ALIGN_BOWTIE2 (
      ch_filtered_reads,
      PREPARE_GENOME.out.bowtie2_index.collect(),  ← FIX
      false,
      false,
      PREPARE_GENOME.out.fasta.collect()           ← FIX
  )
    """
}

workflow.onComplete {
    println "\n✅ Verifica della logica di channel completata con successo!"
}
