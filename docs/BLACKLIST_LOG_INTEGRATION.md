# Blacklist Removal Log Integration

## Overview

Il processo `BLACKLIST_LOG` è stato integrato nel workflow ChIP-seq per tracciare quante reads vengono rimosse durante il filtering delle blacklist regions.

## Posizione nel Workflow

Il log viene generato **PRIMA** del processo di filtering `BAM_FILTER_SUBWF`, analizzando i BAM file dopo:
- Merge delle librerie (`PICARD_MERGESAMFILES`)
- Marking dei duplicati (`MARK_DUPLICATES_PICARD`)

Questo permette di vedere l'impatto della blacklist sul dataset completo prima di applicare gli altri filtri.

## Files Generati

### Location
```
results/
└── bowtie2/  (o altro aligner specificato)
    └── mergedLibrary/
        └── blacklist_metrics/
            ├── SAMPLE1.blacklist.log
            ├── SAMPLE2.blacklist.log
            └── ...
```

Il path dinamico è: `${params.outdir}/${params.aligner}/mergedLibrary/blacklist_metrics/`

### Formato del Log

```
========================================================================
BLACKLIST FILTERING LOG - Sample: H3K27ac_rep1
========================================================================

Date: 2026-04-14 08:55:00
Input BAM: H3K27ac_rep1.mLb.mkD.sorted.bam
Blacklist: hg38-blacklist.v2.bed

------------------------------------------------------------------------
STATISTICS
------------------------------------------------------------------------

Total reads in input BAM:                  10,000,000

Reads IN blacklist regions:                   500,000  (5.00%)
Reads OUTSIDE blacklist (retained):         9,500,000  (95.00%)

Number of blacklist regions:                    1,234

------------------------------------------------------------------------
SUMMARY
------------------------------------------------------------------------

Reads removed:     500,000 (5.00%)
Reads retained:    9,500,000 (95.00%)

========================================================================
```

## Quando Viene Eseguito

Il processo viene eseguito **SOLO** se:
```groovy
if (params.blacklist) {
    BLACKLIST_LOG(...)
}
```

Quindi:
- ✅ **Con blacklist**: `--blacklist /path/to/blacklist.bed` → genera i log
- ❌ **Senza blacklist**: nessun log generato

## Implementazione

### Modulo
- **File**: `modules/local/blacklist_log.nf`
- **Container**: `mulled-v2-8186960447c5cb2faa697666dc1e6d919ad23f3e` (bedtools + samtools)
- **Label**: `process_low` (richiede poche risorse)

### Workflow
- **File**: `workflows/chipseq.nf` (linee ~285-295)
- **Input**: BAM dopo mark duplicates + BAI + blacklist BED
- **Output**: File `.blacklist.log` pubblicato in `${params.outdir}/${params.aligner}/mergedLibrary/blacklist_metrics/`

## Statistiche Calcolate

1. **Total reads**: Conteggio totale reads nel BAM input
2. **Reads in blacklist**: Reads che si sovrappongono alle blacklist regions
3. **Reads retained**: Reads che NON sono nelle blacklist (= total - blacklist)
4. **Percentages**: % rimosse e % mantenute
5. **Blacklist regions**: Numero di regioni nel file blacklist

## Utilizzo delle Informazioni

### Valutazione Qualità
- **< 1%** rimosso: Eccellente, poche reads problematiche
- **1-5%** rimosso: Buono, normale per la maggior parte dei genomi
- **5-10%** rimosso: Accettabile, alcune regioni problematiche
- **> 10%** rimosso: ⚠️ Verificare la qualità dei dati o il file blacklist

### Troubleshooting
Se la percentuale è molto alta (>10%):
1. Verificare che il file blacklist corrisponda al genome assembly
2. Controllare la qualità dell'allineamento (mapping quality)
3. Valutare se ci sono problemi con l'arricchimento in regioni ripetitive

## Script Standalone

Uno script bash standalone è disponibile in:
```
scripts/blacklist_removal_log.sh
```

Uso:
```bash
./scripts/blacklist_removal_log.sh INPUT.bam blacklist.bed output.log
```

## Container e Dipendenze

- **bedtools** ≥ 2.30.0: Per intersezione BAM/BED
- **samtools** ≥ 1.15.1: Per conteggio reads

Automaticamente gestite dal container Biocontainers.
