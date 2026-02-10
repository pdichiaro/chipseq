# 🔍 CONFRONTO OUTPUT: Cosa Cambia REALMENTE?

## RISPOSTA RAPIDA
✅ **OUTPUT FILE IDENTICO** - Stessa struttura CSV  
✅ **NAMING CONVENTION IDENTICA** - Stesso formato `{sample}_REP{x}_T{y}`  
⚠️ **COLONNA REPLICATE AGGIUNTA** - Una colonna extra nell'output

---

## 📋 FORMATO OUTPUT VALIDATO

### TUO SCRIPT ATTUALE (pdichiaro)
**Input samplesheet**:
```csv
sample,fastq_1,fastq_2,antibody,control
WT_BCATENIN_IP_REP1,IP1_R1.fq.gz,IP1_R2.fq.gz,BCATENIN,WT_INPUT_REP1
WT_BCATENIN_IP_REP2,IP2_R1.fq.gz,IP2_R2.fq.gz,BCATENIN,WT_INPUT_REP2
WT_INPUT_REP1,IN1_R1.fq.gz,IN1_R2.fq.gz,,
WT_INPUT_REP2,IN2_R1.fq.gz,IN2_R2.fq.gz,,
```

**Output validato** (`samplesheet.valid.csv`):
```csv
sample,single_end,fastq_1,fastq_2,antibody,control
WT_BCATENIN_IP_REP1_T1,0,IP1_R1.fq.gz,IP1_R2.fq.gz,BCATENIN,WT_INPUT_REP1
WT_BCATENIN_IP_REP2_T1,0,IP2_R1.fq.gz,IP2_R2.fq.gz,BCATENIN,WT_INPUT_REP2
WT_INPUT_REP1_T1,0,IN1_R1.fq.gz,IN1_R2.fq.gz,,
WT_INPUT_REP2_T1,0,IN2_R1.fq.gz,IN2_R2.fq.gz,,
```

**Colonne**: `sample, single_end, fastq_1, fastq_2, antibody, control` (6 colonne)

---

### SCRIPT NF-CORE
**Input samplesheet**:
```csv
sample,fastq_1,fastq_2,replicate,antibody,control,control_replicate
WT_BCATENIN_IP,IP1_R1.fq.gz,IP1_R2.fq.gz,1,BCATENIN,WT_INPUT,1
WT_BCATENIN_IP,IP2_R1.fq.gz,IP2_R2.fq.gz,2,BCATENIN,WT_INPUT,2
WT_INPUT,IN1_R1.fq.gz,IN1_R2.fq.gz,1,,,
WT_INPUT,IN2_R1.fq.gz,IN2_R2.fq.gz,2,,,
```

**Output validato** (`samplesheet.valid.csv`):
```csv
sample,single_end,fastq_1,fastq_2,replicate,antibody,control
WT_BCATENIN_IP_REP1_T1,0,IP1_R1.fq.gz,IP1_R2.fq.gz,1,BCATENIN,WT_INPUT_REP1
WT_BCATENIN_IP_REP2_T1,0,IP2_R1.fq.gz,IP2_R2.fq.gz,2,BCATENIN,WT_INPUT_REP2
WT_INPUT_REP1_T1,0,IN1_R1.fq.gz,IN1_R2.fq.gz,1,,
WT_INPUT_REP2_T1,0,IN2_R1.fq.gz,IN2_R2.fq.gz,2,,
```

**Colonne**: `sample, single_end, fastq_1, fastq_2, replicate, antibody, control` (7 colonne)

---

## 🎯 DIFFERENZE CHIAVE NELL'OUTPUT

### 1. **NUMERO DI COLONNE**
| Script | Colonne Output | Colonna Extra |
|--------|----------------|---------------|
| **pdichiaro** | 6 | - |
| **nf-core** | 7 | `replicate` (colonna 5) |

### 2. **SAMPLE NAME CONSTRUCTION**
Entrambi usano **ESATTAMENTE** lo stesso formato:

```python
# TUO SCRIPT (pdichiaro)
sample_id = f"{sample}_T{idx+1}"
# Output: WT_BCATENIN_IP_REP1_T1 (assumendo sample già include _REP1)

# SCRIPT NF-CORE  
sample_id = "{}_REP{}_T{}".format(sample, replicate, idx + 1)
# Output: WT_BCATENIN_IP_REP1_T1 (costruisce _REP1)
```

**RISULTATO FINALE IDENTICO**: `WT_BCATENIN_IP_REP1_T1`

### 3. **CONTROL FIELD**
| Script | Control Output |
|--------|----------------|
| **pdichiaro** | `WT_INPUT_REP1` (come da input) |
| **nf-core** | `WT_INPUT_REP1` (costruito da control + control_replicate) |

**RISULTATO FINALE IDENTICO**: `WT_INPUT_REP1`

---

## ⚙️ IMPATTO SUL WORKFLOW NEXTFLOW

### Parsing del samplesheet.valid.csv nel workflow

**TUO WORKFLOW ATTUALE**:
```groovy
// Probabilmente legge 6 colonne
Channel
    .fromPath(params.input)
    .splitCsv(header:true, sep:',')
    .map { row -> 
        def meta = [:]
        meta.id = row.sample
        meta.single_end = row.single_end.toBoolean()
        [ meta, [ file(row.fastq_1), file(row.fastq_2) ] ]
    }
```

**CON SCRIPT NF-CORE** (richiede aggiornamento):
```groovy
// Deve leggere 7 colonne includendo replicate
Channel
    .fromPath(params.input)
    .splitCsv(header:true, sep:',')
    .map { row -> 
        def meta = [:]
        meta.id = row.sample
        meta.single_end = row.single_end.toBoolean()
        meta.replicate = row.replicate  // ⚠️ NUOVA COLONNA
        [ meta, [ file(row.fastq_1), file(row.fastq_2) ] ]
    }
```

---

## 🔧 COSA DEVI MODIFICARE NEL WORKFLOW?

### ✅ SE il workflow NON usa la colonna `replicate`:
**NESSUNA MODIFICA NECESSARIA** - La colonna extra viene ignorata

### ⚠️ SE il workflow estrae replicate dal nome del sample:
**DEVI AGGIORNARE** per usare la colonna `replicate`

Esempio:
```groovy
// VECCHIO APPROCCIO (estrae da nome)
meta.replicate = meta.id.split('_REP')[1].split('_')[0]
// Input: "WT_BCATENIN_IP_REP1_T1" → Output: "1"

// NUOVO APPROCCIO (usa colonna)
meta.replicate = row.replicate
// Input: colonna replicate → Output: "1"
```

---

## 📊 VANTAGGI COLONNA REPLICATE ESPLICITA

### Scenario: Peak calling con replicati

**ATTUALE (tuo script)**:
```groovy
// Deve parsare il nome per estrarre replicate
process MACS2_CALLPEAK {
    input:
    tuple val(meta), path(bam)
    
    script:
    def rep = meta.id.tokenize('_REP')[1].tokenize('_')[0]  // Parsing manuale!
    """
    macs2 callpeak \\
        --name ${meta.id}_rep${rep} \\
        ...
    """
}
```

**CON NF-CORE**:
```groovy
// Replicate già disponibile nel meta
process MACS2_CALLPEAK {
    input:
    tuple val(meta), path(bam)
    
    script:
    """
    macs2 callpeak \\
        --name ${meta.id}_rep${meta.replicate} \\  // Diretto!
        ...
    """
}
```

### Scenario: Grouping per merge

**ATTUALE**:
```groovy
// Raggruppa per sample base (rimuovendo _REP e _T)
.groupTuple(by: [0])  // Complicato definire key
```

**CON NF-CORE**:
```groovy
// Raggruppa usando meta.replicate
.map { meta, files -> 
    def base_sample = meta.id.tokenize('_REP')[0]
    [ [id: base_sample, replicate: meta.replicate], files ]
}
.groupTuple(by: [0, 1])  // Group by sample + replicate
```

---

## 🚨 BREAKING CHANGES

### ✅ NON BREAKING (maggior parte dei casi)
Se il tuo workflow:
- Usa solo `meta.id` per identificare samples
- Non fa parsing del replicate dal nome
- Non raggruppa per replicate

→ **FUNZIONERÀ SENZA MODIFICHE** (colonna extra ignorata)

### ⚠️ POTENTIALLY BREAKING
Se il tuo workflow:
- Estrae replicate dal nome con regex/split
- Fa grouping complesso per replicate
- Usa convenzioni di naming specifiche

→ **RICHIEDE AGGIORNAMENTI** ma diventa più robusto

---

## 📝 RACCOMANDAZIONI

### 1. **Verifica il workflow principale**
```bash
cd chipseq
grep -n "replicate" workflows/*.nf subworkflows/*.nf
grep -n "REP" workflows/*.nf subworkflows/*.nf
grep -n "split.*REP" workflows/*.nf subworkflows/*.nf
```

Cerca pattern come:
- `split('_REP')`
- `tokenize('REP')`
- Estrazione manuale di replicate

### 2. **Test con dati di esempio**
Prima di committare:
1. Sostituisci `check_samplesheet.py`
2. Crea samplesheet test in formato nf-core
3. Esegui workflow in dry-run:
```bash
nextflow run main.nf -profile test,docker --input test_nfcore_format.csv -resume --dry-run
```

### 3. **Aggiorna gradualmente**
- **Step 1**: Sostituisci script validazione
- **Step 2**: Testa con samplesheet nf-core format
- **Step 3**: Se workflow usa replicate, aggiorna parsing
- **Step 4**: Aggiorna documentazione

---

## 🎬 COSA SUCCEDE REALMENTE?

### INPUT TRANSFORMATION

#### Formato Attuale (pdichiaro)
```
INPUT:  WT_IP_REP1 → OUTPUT: WT_IP_REP1_T1
        WT_IP_REP2 → OUTPUT: WT_IP_REP2_T1
```
Replicate **nel nome**, script appende solo `_T{idx}`

#### Formato nf-core
```
INPUT:  WT_IP (rep=1) → OUTPUT: WT_IP_REP1_T1 
        WT_IP (rep=2) → OUTPUT: WT_IP_REP2_T1
```
Replicate **costruito**, script appende `_REP{rep}_T{idx}`

### RISULTATO FINALE
**NOMI SAMPLE IDENTICI** nel file `.valid.csv`!

---

## ✅ CONCLUSIONE

### Cambiano:
1. ✅ **Validazioni** (più robuste)
2. ✅ **Input format** (colonne replicate/control_replicate)
3. ✅ **Output colonne** (+1 colonna: replicate)
4. ✅ **Internal logic** (dizionario annidato)

### NON Cambiano:
1. ✅ **Sample naming** (stesso formato `_REP{x}_T{y}`)
2. ✅ **Control naming** (stesso formato)
3. ✅ **Numero di righe output** (stesso)
4. ✅ **Workflow compatibility** (se non usa replicate field)

---

## 🎯 PROSSIMO PASSO

**Domanda per te**: Il tuo workflow **usa** o **estrae** il replicate dal nome del sample?

1. **NO** → Puoi procedere con sostituzione diretta ✅
2. **SÌ** → Devi identificare dove e aggiornare parsing ⚠️

Vuoi che controlli il tuo workflow per identificare potenziali breaking changes?
