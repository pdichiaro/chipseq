#!/usr/bin/env nextflow
nextflow.enable.dsl=2

/*
 * Test script per verificare il sistema di warning MACS2 zero peaks
 * Simula l'output di MACS2_CALLPEAK con campioni che hanno 0 e >0 peaks
 */

workflow {
    // Simula output MACS2 con mix di successi e fallimenti
    def test_data = channel.of(
        [[id: 'sample1_success'], file('test_peaks_1.narrowPeak')],
        [[id: 'sample2_ZERO_PEAKS'], []],  // Empty list = 0 peaks
        [[id: 'sample3_success'], file('test_peaks_3.narrowPeak')],
        [[id: 'sample4_ZERO_PEAKS'], []]   // Another failure
    )

    // Applica la logica di branching/warning (copiata dal workflow principale)
    test_data
        .branch { meta, peaks ->
            passed: peaks.size() > 0
                return [meta, peaks]
            failed: true
                return [meta, peaks]
        }
        .set { ch_branched }

    // Warning per campioni falliti
    ch_branched
        .failed
        .subscribe { meta, peaks ->
            log.warn """
            ╔════════════════════════════════════════════════════════════════════════════════╗
            ║                          ⚠️  MACS2 ZERO PEAKS WARNING                          ║
            ╚════════════════════════════════════════════════════════════════════════════════╝
            
            Sample '${meta.id}' produced 0 peaks from MACS2 peak calling.
            This sample will be excluded from downstream analysis.
            """.stripIndent()
        }

    // Check se TUTTI falliscono
    ch_branched
        .passed
        .count()
        .subscribe { count ->
            if (count == 0) {
                log.error """
                ╔════════════════════════════════════════════════════════════════════════════════╗
                ║                      🔴 CRITICAL: ALL SAMPLES FAILED                           ║
                ╚════════════════════════════════════════════════════════════════════════════════╝
                
                ALL samples produced 0 peaks from MACS2 peak calling!
                """.stripIndent()
            } else {
                log.info "✅ MACS2 peak calling successful for ${count} sample(s)"
            }
        }

    // Output finale
    ch_branched
        .passed
        .view { meta, peaks -> "✅ Passed: ${meta.id}" }
}
