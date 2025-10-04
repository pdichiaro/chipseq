# Miglioramenti al Log di Filtraggio BAM

## Problema Identificato

Il precedente modulo `BLACKLIST_LOG` generava un log chiamato "Blacklist Filtering Log" ma in realtà contava **TUTTE** le reads rimosse da tutti i filtri combinati, non solo quelle rimosse dalla blacklist.

### Filtri applicati nel processo `BAM_FILTER`:

1. **Duplicati**: rimossi con flag `-F 0x0400` (se `keep_dups = false`)
2. **Blacklist**: rimosse con `-L include_regions.bed`
3. **Multi-mappers**: rimossi con `-q 1` (MAPQ < 1)
4. **Fragment size**: rimossi con filtro `awk` (> 500bp default)
5. **Secondary/Supplementary**: rimossi con `-F 0x0100 -F 0x0800`
6. **Unmapped**: rimossi con `-F 0x004 -F 0x0008`

### Confronto BAM:

- **BAM BEFORE**: Output di `MARK_DUPLICATES_PICARD` (duplicati marcati ma presenti, reads in blacklist presenti)
- **BAM AFTER**: Output di `BAM_FILTER` (TUTTI i filtri applicati)

Il log precedente mostrava **60.75%** di reads rimosse, ma includeva **tutti i filtri**, non solo la blacklist!

---

## Soluzione Implementata

### Modifiche ai file:

#### 1. `subworkflows/local/prepare_genome.nf`
- **Aggiunto**: Emissione del file blacklist originale (`ch_blacklist`)
- **Motivo**: Per poter contare le reads che overlappano le regioni blacklist

```groovy
emit:
    blacklist = ch_blacklist  // path: blacklist.bed (original)
```

#### 2. `modules/local/blacklist_log.nf`
- **Rinominato output**: `*.blacklist.log` → `*.filtering.log`
- **Cambiata directory publish**: `blacklist_metrics` → `filtering_metrics`
- **Aggiunto input**: `path blacklist_bed` (file blacklist originale)
- **Nuovo calcolo**:
  - `READS_IN_BLACKLIST`: conta reads che overlappano blacklist usando `samtools view -c -L ${blacklist_bed}`
  - `DUPLICATES_MARKED`: conta duplicati marcati con `samtools view -c -f 0x0400`
  - `OTHER_FILTERS`: calcola reads rimosse da altri filtri (MAPQ, fragment size, etc.)

#### 3. `workflows/chipseq.nf`
- **Aggiunto parametro**: `PREPARE_GENOME.out.blacklist.first()` alla chiamata di `BLACKLIST_LOG`
- **Aggiornato commento**: Chiarisce che il log mostra tutti i filtri, non solo blacklist

---

## Nuovo Output del Log

Il file `*.filtering.log` ora mostra:

```
========================================================================
BAM FILTERING LOG - Sample: sample_name
========================================================================

Date: 2026-04-14 14:53:09
Input BAM (MARK_DUPLICATES):   sample.mLb.mkD.bam
Output BAM (after filtering):  sample.mLb.mkD.filter2.bam
Blacklist file:                hg38.blacklist.bed

------------------------------------------------------------------------
FILTERING STATISTICS
------------------------------------------------------------------------

Total reads (input):                      10,000,000

Reads overlapping blacklist regions:       1,500,000  (15.00%)
Duplicate reads (marked by Picard):        3,000,000  (30.00%)
Reads removed by other filters*:           2,575,000  (25.75%)
  (*MAPQ < 1, fragment size > 500bp, secondary/supplementary alignments)

------------------------------------------------------------------------
TOTAL FILTERING IMPACT
------------------------------------------------------------------------

Total reads REMOVED (all filters):         6,075,000  (60.75%)
Total reads RETAINED:                      3,925,000  (39.25%)

Number of blacklist regions:                   1,234

------------------------------------------------------------------------
NOTE
------------------------------------------------------------------------
- Blacklist count shows reads overlapping blacklist regions
- Duplicate count shows reads marked by Picard MarkDuplicates
- Other filters include: multi-mappers (MAPQ<1), large fragments (>500bp),
  secondary/supplementary alignments, unmapped reads
- Some reads may be counted in multiple categories (e.g., a duplicate
  read in a blacklist region contributes to both counts)

========================================================================
```

---

## Vantaggi della Nuova Implementazione

✅ **Trasparenza**: Separa chiaramente i diversi tipi di filtri applicati

✅ **Accuratezza**: Conta esattamente le reads in blacklist usando `samtools view -L`

✅ **Tracciabilità**: Mostra duplicati, blacklist, e altri filtri separatamente

✅ **Documentazione**: Note chiare sul significato di ogni metrica

⚠️ **Nota importante**: Le categorie possono sovrapporsi (es. una read duplicata in blacklist viene contata in entrambe)

---

## Come Usare

Dopo aver applicato le modifiche, esegui:

```bash
# Pulisci cache Nextflow
rm -rf .nextflow* work/

# Esegui la pipeline
nextflow run main.nf --input samplesheet.csv --genome hg38 --blacklist hg38.blacklist.bed

# Controlla i log
cat results/bowtie2/mergedLibrary/filtering_metrics/*.filtering.log
```

---

## Testing

Per verificare che i calcoli siano corretti:

```bash
# Conta manualmente reads in blacklist
samtools view -c -L blacklist.bed sample.mLb.mkD.bam

# Conta duplicati marcati
samtools view -c -f 0x0400 sample.mLb.mkD.bam

# Verifica che i numeri nel log corrispondano
```

---

## Autore

Modifiche implementate il 2026-04-14 per risolvere l'issue di calcolo accurato delle reads rimosse da blacklist filtering.
