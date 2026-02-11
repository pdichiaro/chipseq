# Fix Applicato: MACS2 Zero Peaks Warning System

## 📋 Problema Risolto

**File modificato**: `workflows/chipseq.nf` (linee ~407-413)

**Problema originale**:
```groovy
// Vecchio codice - SILENT FILTER
MACS2_CALLPEAK_SINGLE
    .out
    .peak
    .filter { meta, peaks -> peaks.size() > 0 }  // ❌ Scarta campioni senza avviso
    .set { ch_macs2_peaks }
```

Il `.filter()` scartava silenziosamente i campioni con 0 peaks da MACS2, causando:
- ❌ Nessun avviso quando campioni individuali falliscono
- ❌ Nessun errore quando TUTTI i campioni falliscono
- ❌ Risultati vuoti inspiegabili
- ❌ Debug difficile per gli utenti

---

## ✅ Soluzione Implementata

**Nuovo codice - WARNING SYSTEM**:
```groovy
// Nuovo codice con sistema di warning/error
MACS2_CALLPEAK_SINGLE
    .out
    .peak
    .branch { meta, peaks ->
        passed: peaks.size() > 0
            return [meta, peaks]
        failed: true
            return [meta, peaks]
    }
    .set { ch_macs2_branched }

// Warning per ogni campione con zero peaks
ch_macs2_branched
    .failed
    .subscribe { meta, peaks ->
        log.warn """
        ╔════════════════════════════════════════════════════════╗
        ║          ⚠️  MACS2 ZERO PEAKS WARNING                  ║
        ╚════════════════════════════════════════════════════════╝
        
        Sample '${meta.id}' produced 0 peaks from MACS2 peak calling.
        This sample will be excluded from downstream analysis.
        
        Possible causes and solutions:
        1. Poor ChIP enrichment
        2. Insufficient sequencing depth
        3. Overly stringent MACS2 parameters
        4. Poor quality control/input sample
        5. Wrong genome size parameter
        6. Biological factors
        """
    }

// Errore critico se TUTTI falliscono
ch_macs2_branched
    .passed
    .count()
    .subscribe { count ->
        if (count == 0) {
            log.error """
            🔴 CRITICAL: ALL SAMPLES FAILED
            ALL samples produced 0 peaks from MACS2!
            [Guida dettagliata per troubleshooting]
            """
        } else {
            log.info "✅ MACS2 peak calling successful for ${count} sample(s)"
        }
    }

// Usa solo campioni che passano
ch_macs2_branched
    .passed
    .set { ch_macs2_peaks }
```

---

## 🎯 Funzionalità Aggiunte

### 1. **Warning Individuali** ⚠️
Ogni campione con 0 peaks emette un warning dettagliato con:
- Nome del campione
- Messaggio chiaro del problema
- 6 possibili cause
- Suggerimenti specifici per ogni causa

### 2. **Errore Critico** 🔴
Se TUTTI i campioni falliscono:
- Emette `log.error` (livello più alto)
- Fornisce guida completa per troubleshooting
- Include 4 aree di intervento immediate

### 3. **Messaggio di Successo** ✅
Quando alcuni campioni passano:
- Conferma il numero di campioni con successo
- Rassicura l'utente che la pipeline procede

---

## 🧪 Verifica

### Test Eseguito
File: `test_macs2_warning_fix.nf`

**Scenario testato**:
- 2 campioni con peaks (`sample1_success`, `sample3_success`) → ✅ PASSANO
- 2 campioni senza peaks (`sample2_ZERO_PEAKS`, `sample4_ZERO_PEAKS`) → ⚠️ WARNING

**Risultato**:
```
✅ Passed: sample1_success
✅ Passed: sample3_success
⚠️  MACS2 ZERO PEAKS WARNING - Sample 'sample2_ZERO_PEAKS' ...
⚠️  MACS2 ZERO PEAKS WARNING - Sample 'sample4_ZERO_PEAKS' ...
✅ MACS2 peak calling successful for 2 sample(s)
```

### Validazione Nextflow
```bash
nextflow lint workflows/chipseq.nf
```
✅ **PASSED** - Nessun errore di sintassi nel codice modificato

---

## 📊 Vantaggi

| Prima | Dopo |
|-------|------|
| ❌ Silent failure | ✅ Warning chiaro per ogni fallimento |
| ❌ Utente confuso | ✅ Guida pratica immediata |
| ❌ Debug difficile | ✅ Feedback immediato con cause |
| ❌ Risultati vuoti inspiegabili | ✅ Spiegazione dettagliata |
| ❌ Nessuna distinzione tra fallimento parziale/totale | ✅ Messaggio appropriato per ogni scenario |

---

## 🔄 Compatibilità

✅ **Backward Compatible**: 
- Non cambia il comportamento della pipeline per campioni con successo
- Il canale output (`ch_macs2_peaks`) contiene gli stessi dati di prima
- Tutti i processi downstream ricevono input identici

✅ **Zero Breaking Changes**:
- Nessuna modifica ai parametri
- Nessuna modifica agli output
- Solo aggiunta di logging informativo

---

## 💡 Come Usare

**Niente da cambiare!** La pipeline funziona esattamente come prima, ma ora:

1. **Quando un campione fallisce**:
   - Vedrai un warning dettagliato nel log
   - Il campione viene automaticamente escluso
   - Gli altri campioni continuano normalmente

2. **Quando tutti falliscono**:
   - Vedrai un errore critico con guida completa
   - Saprai esattamente cosa controllare
   - Avrai suggerimenti specifici per ogni area

3. **Quando tutto va bene**:
   - Vedrai solo il messaggio di successo
   - Nessun rumore nel log

---

## 📝 File Correlati

- **Codice modificato**: `workflows/chipseq.nf` (linee ~407-500)
- **Test**: `test_macs2_warning_fix.nf`
- **Documentazione**: `FIX_MACS2_ZERO_PEAKS_WARNING.md` (questo file)

---

## 🚀 Status

✅ **IMPLEMENTATO**  
✅ **TESTATO**  
✅ **VALIDATO**  
✅ **DOCUMENTATO**  

**Data**: 2026-02-11  
**Version**: 1.0  
**Author**: Seqera AI

---

## 🔍 Riferimenti

Questo fix è basato sulla soluzione implementata per il **Bug #8** del progetto nf-core/chipseq, adattato specificamente per la tua pipeline che usa MACS2 (invece di MACS3).

La soluzione segue le best practices di Nextflow DSL2:
- Usa `.branch()` invece di `.filter()` per separare successi/fallimenti
- Usa `.subscribe()` per side-effects (logging) senza modificare il canale
- Usa `.count()` per rilevare fallimento completo
- Mantiene tutti i canali immutabili e composibili

---

## 📞 Supporto

Per domande o problemi:
1. Controlla i log della pipeline (`.nextflow.log`)
2. Verifica i warning MACS2 nel console output
3. Segui i suggerimenti nelle guide di troubleshooting
4. Controlla i report MultiQC per metriche di qualità

