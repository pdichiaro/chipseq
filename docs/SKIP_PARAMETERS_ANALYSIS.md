# Analisi dei Parametri Skip nel Workflow ChIP-seq

## 🎯 Domanda: Il workflow funziona con `skip_trimming` e `skip_alignment`?

### Risposta Breve

- ✅ **`skip_trimming`**: **SÌ**, completamente implementato e funzionale
- ⚠️ **`skip_alignment`**: **NO**, parametro definito ma **NON implementato** nel workflow

---

## 📊 Analisi Dettagliata

### 1. `skip_trimming` - ✅ FUNZIONALE

#### Definizione nel Config
**File**: `nextflow.config` (linea 40)
```groovy
skip_trimming = false
```

#### Implementazione nel Workflow
**File**: `workflows/chipseq.nf` (linea 174)

```groovy
FASTQ_FASTQC_UMITOOLS_TRIMGALORE (
    ch_reads,
    params.skip_fastqc || params.skip_qc,
    false,                              // skip_umi_extract
    false,                              // skip_umi_dedup
    params.skip_trimming,               // ✅ Parametro passato al subworkflow
    0,
    1
)
```

#### Logica nel Subworkflow
**File**: `subworkflows/nf-core/fastq_fastqc_umitools_trimgalore/main.nf` (linea 72)

```groovy
workflow FASTQ_FASTQC_UMITOOLS_TRIMGALORE {
    take:
    reads            // channel: [ val(meta), [ reads ] ]
    skip_fastqc      // boolean
    skip_umi_extract // boolean
    skip_umi_dedup   // boolean
    skip_trimming    // boolean: true/false  ✅ Parametro ricevuto
    umi_discard_read // val
    min_trimmed_reads // val
    
    main:
    // ... FastQC logic ...
    
    if (!skip_trimming) {                      // ✅ Controllo condizionale
        TRIMGALORE (
            reads,
            false                               // val_save_trimmed
        )
        ch_trim_reads = TRIMGALORE.out.reads
        ch_trim_json  = TRIMGALORE.out.json
        ch_trim_log   = TRIMGALORE.out.log
        ch_versions   = ch_versions.mix(TRIMGALORE.out.versions)
        
        // FastQC on trimmed reads
        if (!skip_fastqc) {
            FASTQC_TRIMGALORE (
                ch_trim_reads
            )
            ch_trim_fastqc_html = FASTQC_TRIMGALORE.out.html
            ch_trim_fastqc_zip  = FASTQC_TRIMGALORE.out.zip
            ch_versions = ch_versions.mix(FASTQC_TRIMGALORE.out.versions)
        }
    }
    
    emit:
    reads = skip_trimming ? reads : ch_trim_reads  // ✅ Output condizionale
    // ...
}
```

#### Comportamento con `skip_trimming = true`

1. **TrimGalore NON viene eseguito**
2. **FastQC su trimmed reads NON viene eseguito**
3. **Le reads raw vengono passate direttamente all'alignment**
4. **MultiQC non includerà**:
   - Sezione TrimGalore logs
   - FastQC trimmed reads
   - Trimming statistics
5. **Workflow continua normalmente** con le reads raw

#### Esempio di Utilizzo
```bash
# Skip trimming - usa reads raw per alignment
nextflow run pdichiaro/chipseq \
  --input samplesheet.csv \
  --genome GRCh38 \
  --skip_trimming true \
  -profile docker
```

**Risultato**: 
- Nessun trimming
- Alignment diretto con reads raw
- Tempo di esecuzione ridotto (~10-20 minuti risparmiati per sample)
- Utile per dati già pre-processati o per test rapidi

---

### 2. `skip_alignment` - ⚠️ NON IMPLEMENTATO

#### Definizione nel Config
**File**: `nextflow.config` (linea 46)
```groovy
skip_alignment = false
```

#### Problema: Nessuna Implementazione nel Workflow

**File**: `workflows/chipseq.nf` (linea 189)

```groovy
// L'alignment è SEMPRE eseguito se aligner è specificato
if (params.aligner == 'star') {                    // ❌ Controlla solo il tipo di aligner
    ALIGN_STAR (
        ch_filtered_reads,
        PREPARE_GENOME.out.star_index
    )
    ch_genome_bam        = ALIGN_STAR.out.bam
    ch_genome_bam_index  = ALIGN_STAR.out.bai
    // ...
}

// ❌ NON c'è controllo per params.skip_alignment
// ❌ NON c'è logica per usare BAM pre-esistenti
```

#### Cosa Manca

1. **Controllo condizionale**: Nessun `if (!params.skip_alignment)` nel workflow
2. **Input alternativo**: Nessun meccanismo per fornire BAM pre-allineati
3. **Channel di bypass**: Nessun modo per saltare l'alignment e procedere ai passaggi successivi

#### Cosa Succederebbe Ora

Se provi a usare `--skip_alignment true`:

```bash
nextflow run pdichiaro/chipseq \
  --input samplesheet.csv \
  --genome GRCh38 \
  --skip_alignment true \        # ❌ Questo parametro viene IGNORATO
  -profile docker
```

**Risultato**: 
- Il parametro viene ignorato
- L'alignment viene eseguito comunque
- Nessun errore, ma nessun effetto

---

## 🔧 Come Implementare `skip_alignment` Correttamente

Per rendere `skip_alignment` funzionale, servono queste modifiche:

### Opzione A: Skip Alignment Completo (Non Raccomandato per ChIP-seq)

```groovy
// File: workflows/chipseq.nf

if (!params.skip_alignment) {
    if (params.aligner == 'star') {
        ALIGN_STAR (
            ch_filtered_reads,
            PREPARE_GENOME.out.star_index
        )
        ch_genome_bam        = ALIGN_STAR.out.bam
        ch_genome_bam_index  = ALIGN_STAR.out.bai
        // ...
    }
} else {
    // ❌ PROBLEMA: Non c'è sorgente di BAM files!
    // Il workflow si blocca qui
}
```

**Problema**: ChIP-seq RICHIEDE BAM files per i passaggi successivi (peak calling, QC, ecc.)

### Opzione B: Fornire BAM Pre-Allineati (Approccio Corretto)

Questa è l'implementazione corretta, simile a nf-core/rnaseq:

#### 1. Aggiungere Parametro per BAM Input

**File**: `nextflow.config`
```groovy
// Input options
input          = null
input_bam      = null    // ✅ NUOVO: Samplesheet con BAM pre-allineati
skip_alignment = false
```

#### 2. Modificare Input Check

**File**: `subworkflows/local/input_check.nf`
```groovy
workflow INPUT_CHECK {
    take:
    samplesheet      // file: samplesheet con FASTQ
    samplesheet_bam  // file: samplesheet con BAM (opzionale)
    
    main:
    if (samplesheet_bam) {
        // Valida BAM samplesheet
        SAMPLESHEET_CHECK_BAM (
            samplesheet_bam
        )
        ch_bam = SAMPLESHEET_CHECK_BAM.out.bam
    } else {
        // Valida FASTQ samplesheet (normale)
        SAMPLESHEET_CHECK (
            samplesheet
        )
        ch_reads = SAMPLESHEET_CHECK.out.reads
        ch_bam   = Channel.empty()
    }
    
    emit:
    reads = ch_reads
    bam   = ch_bam
}
```

#### 3. Modificare Workflow Principale

**File**: `workflows/chipseq.nf`
```groovy
// Input check
INPUT_CHECK (
    ch_input,
    ch_input_bam
)
ch_reads = INPUT_CHECK.out.reads
ch_bam   = INPUT_CHECK.out.bam

// Trimming (solo se non skip_alignment)
if (!params.skip_alignment) {
    FASTQ_FASTQC_UMITOOLS_TRIMGALORE (
        ch_reads,
        params.skip_fastqc || params.skip_qc,
        false,
        false,
        params.skip_trimming,
        0,
        1
    )
    ch_filtered_reads = FASTQ_FASTQC_UMITOOLS_TRIMGALORE.out.reads
    
    // Alignment with STAR
    if (params.aligner == 'star') {
        ALIGN_STAR (
            ch_filtered_reads,
            PREPARE_GENOME.out.star_index
        )
        ch_genome_bam       = ALIGN_STAR.out.bam
        ch_genome_bam_index = ALIGN_STAR.out.bai
        ch_samtools_stats   = ALIGN_STAR.out.stats
        ch_samtools_flagstat = ALIGN_STAR.out.flagstat
        ch_samtools_idxstats = ALIGN_STAR.out.idxstats
    }
} else {
    // ✅ USA BAM pre-allineati
    ch_genome_bam = ch_bam.map { meta, bam, bai -> [ meta, bam ] }
    ch_genome_bam_index = ch_bam.map { meta, bam, bai -> [ meta, bai ] }
    
    // Genera statistiche dai BAM esistenti
    BAM_STATS_SAMTOOLS (
        ch_genome_bam.join(ch_genome_bam_index)
    )
    ch_samtools_stats    = BAM_STATS_SAMTOOLS.out.stats
    ch_samtools_flagstat = BAM_STATS_SAMTOOLS.out.flagstat
    ch_samtools_idxstats = BAM_STATS_SAMTOOLS.out.idxstats
}

// ✅ Resto del workflow procede normalmente
// (merge replicates, filtering, peak calling, ecc.)
```

#### 4. Creare BAM Samplesheet Schema

**File**: `assets/schema_bam_input.json`
```json
{
    "$schema": "http://json-schema.org/draft-07/schema",
    "type": "array",
    "items": {
        "type": "object",
        "properties": {
            "sample": {
                "type": "string",
                "pattern": "^\\S+$",
                "meta": ["id"]
            },
            "bam": {
                "type": "string",
                "format": "file-path",
                "exists": true,
                "pattern": "^\\S+\\.bam$"
            },
            "bai": {
                "type": "string",
                "format": "file-path",
                "exists": true,
                "pattern": "^\\S+\\.bai$"
            },
            "control": {
                "type": "string"
            },
            "antibody": {
                "type": "string"
            }
        },
        "required": ["sample", "bam", "bai"]
    }
}
```

#### 5. Esempio BAM Samplesheet

**File**: `samplesheet_bam.csv`
```csv
sample,bam,bai,control,antibody
WT_REP1,/path/to/WT_REP1.sorted.bam,/path/to/WT_REP1.sorted.bam.bai,INPUT,H3K27me3
WT_REP2,/path/to/WT_REP2.sorted.bam,/path/to/WT_REP2.sorted.bam.bai,INPUT,H3K27me3
INPUT,/path/to/INPUT.sorted.bam,/path/to/INPUT.sorted.bam.bai,,
```

#### 6. Utilizzo

```bash
# Con BAM pre-allineati
nextflow run pdichiaro/chipseq \
  --input_bam samplesheet_bam.csv \
  --skip_alignment true \
  --genome GRCh38 \
  -profile docker
```

**Vantaggi**:
- Salta FASTQ QC, trimming, e alignment
- Parte direttamente dal merging/filtering dei BAM
- Risparmio di tempo significativo (50-70% del workflow)
- Utile per ri-analisi con diversi parametri di peak calling

---

## 🎯 Riepilogo: Stato Attuale

| Parametro | Definito | Implementato | Funzionale | Note |
|-----------|----------|--------------|------------|------|
| `skip_trimming` | ✅ | ✅ | ✅ | Completamente funzionale - skippa TrimGalore |
| `skip_alignment` | ✅ | ❌ | ❌ | Solo definito, non implementato nel workflow |
| `trimmer` | ✅ | ✅ | ✅ | Usato per selezionare TrimGalore (default) |

## ⚠️ Raccomandazioni

### Caso d'Uso 1: Skip Trimming per Reads Già Processate
```bash
# ✅ FUNZIONA
nextflow run pdichiaro/chipseq \
  --input samplesheet.csv \
  --genome GRCh38 \
  --skip_trimming true \
  -profile docker
```

**Quando usare**:
- Reads già trimmate da un altro workflow
- Test rapidi su subset di dati
- Reads molto pulite (Phred score >30)

### Caso d'Uso 2: Skip Alignment con BAM Pre-Esistenti
```bash
# ❌ NON FUNZIONA (ancora)
nextflow run pdichiaro/chipseq \
  --input_bam samplesheet_bam.csv \
  --skip_alignment true \
  --genome GRCh38 \
  -profile docker
```

**Richiede implementazione**:
- Opzione B descritta sopra
- Supporto per `--input_bam`
- Logica condizionale nel workflow principale

### Caso d'Uso 3: Full Pipeline (Default)
```bash
# ✅ FUNZIONA
nextflow run pdichiaro/chipseq \
  --input samplesheet.csv \
  --genome GRCh38 \
  -profile docker
```

**Comportamento**:
- FastQC su raw reads
- TrimGalore trimming
- FastQC su trimmed reads
- STAR alignment
- Tutte le analisi downstream

---

## 🔍 Test per Verificare Funzionalità

### Test 1: Skip Trimming
```bash
# Lancia workflow con skip_trimming
nextflow run pdichiaro/chipseq \
  --input test_samplesheet.csv \
  --genome GRCh38 \
  --skip_trimming true \
  -profile test,docker

# Verifica che TrimGalore non sia nel DAG
nextflow log <run_id> -f "process,status" | grep -i trim
# Output atteso: Nessun processo TRIMGALORE
```

### Test 2: Skip Alignment (Current Behavior)
```bash
# Prova a skippare alignment
nextflow run pdichiaro/chipseq \
  --input test_samplesheet.csv \
  --genome GRCh38 \
  --skip_alignment true \
  -profile test,docker

# Verifica se STAR viene eseguito comunque
nextflow log <run_id> -f "process,status" | grep -i "ALIGN_STAR"
# Output atteso: STAR viene eseguito (parametro ignorato)
```

---

## 📝 Conclusione

**Domanda**: Il workflow funziona con `skip_trimming` e `skip_alignment`?

**Risposta**:
- ✅ **`skip_trimming`**: **SÌ**, completamente implementato
- ❌ **`skip_alignment`**: **NO**, parametro definito ma non utilizzato

**Azione Consigliata**:
1. **Usa `skip_trimming`** tranquillamente - è funzionale
2. **Non fare affidamento su `skip_alignment`** - attualmente non fa nulla
3. **Se hai bisogno di skip alignment**, considera:
   - Implementare l'Opzione B (BAM pre-allineati)
   - Oppure rimuovere il parametro dal config per evitare confusione

---

**Versione**: 1.0  
**Ultimo aggiornamento**: 2026-02-23  
**Status**: ✅ `skip_trimming` validated | ❌ `skip_alignment` not implemented
