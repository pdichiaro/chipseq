# 🚀 Quick Start: MACS2 Zero Peaks Warning Fix

## Cos'è stato fatto?

Ho applicato un **sistema di warning/error** alla tua pipeline ChIP-seq per gestire campioni con 0 peaks chiamati da MACS2.

---

## 📍 Cosa vedrai ora

### Scenario 1: Alcuni campioni falliscono ⚠️

Quando un campione produce 0 peaks, vedrai:

```
WARN: 
╔════════════════════════════════════════════════════════════╗
║          ⚠️  MACS2 ZERO PEAKS WARNING                      ║
╚════════════════════════════════════════════════════════════╝

Sample 'my_sample_X' produced 0 peaks from MACS2 peak calling.
This sample will be excluded from downstream analysis.

Possible causes and solutions:
1. Poor ChIP enrichment
2. Insufficient sequencing depth
3. Overly stringent MACS2 parameters
4. Poor quality control/input sample
5. Wrong genome size parameter
6. Biological factors
```

La pipeline **continua normalmente** con gli altri campioni.

---

### Scenario 2: Tutti i campioni falliscono 🔴

Quando TUTTI i campioni producono 0 peaks, vedrai:

```
ERROR: 
╔════════════════════════════════════════════════════════════╗
║          🔴 CRITICAL: ALL SAMPLES FAILED                   ║
╚════════════════════════════════════════════════════════════╝

ALL samples produced 0 peaks from MACS2 peak calling!
The pipeline cannot continue with downstream analysis.

IMMEDIATE ACTIONS REQUIRED:
1. Review MACS2 parameters
2. Verify input data quality
3. Check ChIP-seq quality
4. Review experimental design
```

---

### Scenario 3: Tutto va bene ✅

Quando almeno un campione ha successo, vedrai:

```
✅ MACS2 peak calling successful for 3 sample(s)
```

La pipeline procede normalmente, solo con feedback positivo!

---

## 🔧 Cosa è stato modificato?

**File**: `workflows/chipseq.nf` (linee ~407-510)

**Prima** (silent filter):
```groovy
MACS2_CALLPEAK_SINGLE.out.peak
    .filter { meta, peaks -> peaks.size() > 0 }
    .set { ch_macs2_peaks }
```
❌ Scartava campioni senza dire nulla

**Dopo** (warning system):
```groovy
MACS2_CALLPEAK_SINGLE.out.peak
    .branch { meta, peaks ->
        passed: peaks.size() > 0
        failed: true
    }
    .set { ch_macs2_branched }

// Warning per ogni fallimento
ch_macs2_branched.failed.subscribe { ... log.warn ... }

// Error se tutti falliscono
ch_macs2_branched.passed.count().subscribe { 
    if (count == 0) { log.error ... }
}

// Output finale
ch_macs2_branched.passed.set { ch_macs2_peaks }
```
✅ Sistema completo di feedback

---

## ✅ Compatibilità

| Aspetto | Status |
|---------|--------|
| **Breaking changes** | ❌ NESSUNO |
| **Parametri modificati** | ❌ NESSUNO |
| **Output modificati** | ❌ NESSUNO |
| **Comportamento pipeline** | ✅ IDENTICO (con logging aggiunto) |

La tua pipeline funziona **esattamente come prima**, solo con feedback migliorato!

---

## 🧪 Come testare

```bash
# La tua pipeline normale
nextflow run workflows/chipseq.nf \
    --input samplesheet.csv \
    --genome GRCh38 \
    --outdir results

# Ora vedrai warning chiari se campioni falliscono!
```

---

## 📚 Documentazione Completa

Per tutti i dettagli tecnici: `FIX_MACS2_ZERO_PEAKS_WARNING.md`

---

## 💡 Vantaggi Immediati

✅ **Saprai subito** quando un campione fallisce  
✅ **Capirai perché** con 6 possibili cause  
✅ **Avrai suggerimenti** specifici per ogni problema  
✅ **Nessuna confusione** su risultati vuoti  
✅ **Debug più rapido** con feedback immediato  

---

## 🎯 Prossimi Passi

1. ✅ **Usa la pipeline normalmente** - non serve fare nulla!
2. 📊 **Leggi i warning** se qualche campione fallisce
3. 🔍 **Segui i suggerimenti** per il troubleshooting
4. 📈 **Verifica le metriche** nei report MultiQC

---

**Data**: 2026-02-11  
**Status**: ✅ READY TO USE

