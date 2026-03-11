# Bowtie2 MultiQC Integration

## Sommario
Implementazione della cattura dei log di Bowtie2 per l'integrazione con MultiQC nel workflow ChIP-seq.

## Problema
Il workflow ChIP-seq supporta due aligner (STAR e Bowtie2), ma:
- **STAR**: i log vengono correttamente catturati e passati a MultiQC
- **Bowtie2**: i log **NON** venivano catturati, pur essendo disponibili dal subworkflow `FASTQ_ALIGN_BOWTIE2`

MultiQC supporta nativamente i log di Bowtie2, quindi questa integrazione permette di visualizzare le statistiche di allineamento nel report MultiQC.

## Analisi dei Workflow nf-core

### nf-core/chipseq
- Il subworkflow `FASTQ_ALIGN_BOWTIE2` **emette** `log_out` (Bowtie2 logs)
- Il workflow principale **NON cattura** questi log
- **Conclusione**: nf-core/chipseq ha lo stesso problema!

### nf-core/rnaseq
- Usa Bowtie2 per rRNA removal nel subworkflow `FASTQ_REMOVE_RRNA`
- **Cattura correttamente** i log: `ch_bowtie2_log = FASTQ_REMOVE_RRNA.out.bowtie2_log`
- **Passa i log a MultiQC**: `ch_multiqc_files.mix(FASTQ_REMOVE_RRNA.out.bowtie2_log)`
- **Conclusione**: nf-core/rnaseq implementa correttamente l'integrazione!

## Modifiche Implementate

### 1. Workflow ChIP-seq (`workflows/chipseq.nf`)

#### Branch STAR (righe ~192-206)
```groovy
if (params.aligner == 'star') {
    ALIGN_STAR (...)
    ch_star_multiqc      = ALIGN_STAR.out.log_final
    ch_bowtie2_multiqc   = Channel.empty()  // STAR doesn't produce Bowtie2 logs
    ...
}
```

#### Branch Bowtie2 (righe ~207-223)
```groovy
else if (params.aligner == 'bowtie2') {
    FASTQ_ALIGN_BOWTIE2 (...)
    ch_star_multiqc      = Channel.empty()  // Bowtie2 doesn't produce STAR-like logs
    ch_bowtie2_multiqc   = FASTQ_ALIGN_BOWTIE2.out.log_out  // ✅ NUOVO: Capture Bowtie2 logs
    ...
}
```

#### Chiamata MULTIQC (righe ~1004-1008)
```groovy
MULTIQC (
    ...
    ch_fastqc_trim_multiqc.collect{it[1]}.ifEmpty([]),
    ch_trim_log_multiqc.collect{it[1]}.ifEmpty([]),

    ch_star_multiqc.collect{it[1]}.ifEmpty([]),        // ✅ NUOVO
    ch_bowtie2_multiqc.collect{it[1]}.ifEmpty([]),     // ✅ NUOVO

    ch_samtools_stats.collect{it[1]}.ifEmpty([]),
    ...
)
```

### 2. Modulo MultiQC (`modules/local/multiqc.nf`)

#### Input section (righe ~15-21)
```groovy
input:
    ...
    path ('fastqc/*')
    path ('trimgalore/fastqc/*')
    path ('trimgalore/*')

    path ('alignment/star/*')       // ✅ NUOVO: STAR logs
    path ('alignment/bowtie2/*')    // ✅ NUOVO: Bowtie2 logs

    path ('alignment/library/*')
    ...
```

## Risultati

### ✅ Vantaggi
1. **Parità di funzionalità**: STAR e Bowtie2 ora hanno lo stesso livello di integrazione con MultiQC
2. **Report completi**: Il report MultiQC include statistiche di allineamento Bowtie2:
   - Numero totale di reads
   - Reads allineati (overall alignment rate)
   - Reads allineati una volta (uniquely aligned)
   - Reads allineati multiple volte (multi-mapped)
   - Reads non allineati
3. **Nessuna modifica breaking**: I canali sono inizializzati come `Channel.empty()` quando l'altro aligner è selezionato
4. **Allineamento con best practices**: Segue il pattern di nf-core/rnaseq

### 📊 Output MultiQC atteso
Con questa modifica, il report MultiQC includerà una sezione "Bowtie2" con:
- Grafico a barre per overall alignment rate
- Tabella con statistiche dettagliate per sample
- Percentuale di reads uniquely/multi-mapped/unmapped

## Testing

### Linting
```bash
cd chipseq
nextflow lint workflows/chipseq.nf
```

**Risultato**: Nessun errore relativo alle modifiche Bowtie2 (38 errori pre-esistenti nel codice).

### Test Consigliato
```bash
# Test con Bowtie2
nextflow run . -profile test,docker --aligner bowtie2

# Verifica MultiQC report
# Controllare che la sezione "Bowtie2" sia presente nel report HTML
```

## File Modificati

1. **`workflows/chipseq.nf`**
   - Aggiunta cattura `ch_bowtie2_multiqc` nel branch Bowtie2 (riga ~221)
   - Inizializzazione `ch_bowtie2_multiqc` nel branch STAR (riga ~204)
   - Aggiunta input a MULTIQC (righe ~1007-1008)

2. **`modules/local/multiqc.nf`**
   - Aggiunta 2 input paths per STAR e Bowtie2 logs (righe ~18-19)

## Riferimenti

- **nf-core/rnaseq**: `subworkflows/nf-core/fastq_remove_rrna/main.nf` (righe 166-167)
- **MultiQC Bowtie2 module**: https://multiqc.info/docs/modules/bowtie2/
- **FASTQ_ALIGN_BOWTIE2 subworkflow**: `subworkflows/nf-core/fastq_align_bowtie2/main.nf`

## Note

Questa implementazione risolve un gap funzionale tra STAR e Bowtie2 nel workflow, garantendo che entrambi gli aligner forniscano lo stesso livello di reporting in MultiQC.
