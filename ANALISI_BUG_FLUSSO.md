# Analisi Bug di Flusso - Pipeline ChIP-seq

## Data Analisi: 2026-02-11

---

## 🔴 BUG CRITICI IDENTIFICATI

### 1. **Gestione Condizionale BigWig Incompleta (Linee 748-758)**

**Problema:** La logica di selezione tra BigWig normalizzato e non normalizzato è incompleta.

```groovy
ch_big_wig = DEEPTOOLS_BIGWIG.out.bigwig

if ( !params.skip_deeptools_norm ) {
    DEEPTOOLS_BIGWIG_NORM (
        ch_bam_bai_scale
    )
    ch_versions = ch_versions.mix(DEEPTOOLS_BIGWIG_NORM.out.versions.first())
    ch_big_wig = DEEPTOOLS_BIGWIG_NORM.out.bigwig
}
```

**Impatto:** Se `params.skip_deeptools_norm` è `true`, viene usato `DEEPTOOLS_BIGWIG.out.bigwig`. Tuttavia, se `ch_bam_bai_scale` è vuoto (nessun fattore di scaling disponibile), il processo `DEEPTOOLS_BIGWIG_NORM` potrebbe fallire.

**Soluzione Raccomandata:**
```groovy
ch_big_wig = DEEPTOOLS_BIGWIG.out.bigwig

if ( !params.skip_deeptools_norm && !ch_size_factors.isEmpty() ) {
    DEEPTOOLS_BIGWIG_NORM (
        ch_bam_bai_scale
    )
    ch_versions = ch_versions.mix(DEEPTOOLS_BIGWIG_NORM.out.versions.first())
    ch_big_wig = DEEPTOOLS_BIGWIG_NORM.out.bigwig
}
```

---

### 2. **Logica di Pairing IP-Control con Bug (Linee 335-362)**

**Problema:** La logica per creare le coppie IP-control ha due percorsi separati ma il secondo percorso (con inputs) può generare duplicati.

```groovy
if(!ch_with_inputs){
    ch_genome_bam_bai
        .map {
            meta, bam, bai -> 
                !meta.is_input ? [ meta , bam, [] ] : null
        }
        .set { ch_ip_control_bam }
    
    ch_ip_control_bam
        .map { ... }
        .groupTuple(by: 0)
        .map { ... }
        .set { ch_antibody_bam }
        
}else{ 
    ch_genome_bam_bai
    .combine(ch_genome_bam_bai)
    .map { 
        meta1, bam1, bai1, meta2, bam2, bai2 ->
            !meta1.is_input && meta1.which_input == meta2.id ? [ meta1, [ bam1 ], [ bam2 ] ] : null
    }
    .set { ch_ip_control_bam } 

    ch_ip_control_bam
        .map { ... }
        .groupTuple(by: 0)
        .map { ... }
        .set { ch_antibody_bam }
}
```

**Impatto:** 
- Nel ramo `else`, `combine` crea un prodotto cartesiano che può essere molto grande
- Se ci sono N samples, vengono create N*N combinazioni, poi filtrate
- Rischio di memory overflow con molti campioni

**Soluzione Raccomandata:**
```groovy
if(!ch_with_inputs){
    // ... codice esistente ...
}else{ 
    // Usa join invece di combine per efficienza
    ch_genome_bam_bai
        .filter { meta, bam, bai -> !meta.is_input }
        .map { meta, bam, bai -> [ meta.which_input, meta, bam, bai ] }
        .join(
            ch_genome_bam_bai
                .filter { meta, bam, bai -> meta.is_input }
                .map { meta, bam, bai -> [ meta.id, bam, bai ] }
        )
        .map { input_id, meta, bam1, bai1, bam2, bai2 ->
            [ meta, [ bam1 ], [ bam2 ] ]
        }
        .set { ch_ip_control_bam }
    
    // ... resto del codice ...
}
```

---

### 3. **Filtro con Valori Null (Linee 337-341 e 346-352)**

**Problema:** Uso di `null` nei map che può causare errori nel channel.

```groovy
.map {
    meta, bam, bai -> 
        !meta.is_input ? [ meta , bam, [] ] : null
}
```

**Impatto:** I valori `null` nei channels possono causare errori downstream o comportamenti inaspettati.

**Soluzione Raccomandata:**
Usare `.filter()` invece di restituire `null`:
```groovy
.filter { meta, bam, bai -> !meta.is_input }
.map { meta, bam, bai -> [ meta , bam, [] ] }
```

---

### 4. **Mancanza di Validazione ch_size_factors (Linea 736)**

**Problema:** Il channel `ch_bam_bai_scale` viene creato combinando BAM con scaling factors, ma non c'è verifica che ogni campione abbia un corrispondente scaling factor.

```groovy
ch_genome_bam_bai
    .combine(ch_size_factors)
    .map { 
        meta1, bam1, bai1, id2, scaling2 ->
            meta1.id == id2 ? [ meta1, bam1, bai1 ,scaling2] : null
    }
    .set { ch_bam_bai_scale }
```

**Impatto:** 
- Se un campione non ha scaling factor, viene scartato silenziosamente (null)
- Possibile perdita di dati senza warning

**Soluzione Raccomandata:**
```groovy
// Contare gli elementi prima e dopo il join
def ch_bam_count = ch_genome_bam_bai.count()
def ch_scaling_count = ch_size_factors.count()

ch_genome_bam_bai
    .map { meta, bam, bai -> [ meta.id, meta, bam, bai ] }
    .join(ch_size_factors, failOnMismatch: true, remainder: true)
    .map { id, meta, bam, bai, scaling ->
        if (scaling == null) {
            log.warn "No scaling factor found for sample: ${id}"
            [ meta, bam, bai, 1.0 ]  // default scaling
        } else {
            [ meta, bam, bai, scaling ]
        }
    }
    .set { ch_bam_bai_scale }
```

---

### 5. **Gestione MultiQC Files per Normalizzazione Condizionale (Linee 680-682)**

**Problema:** I channels MultiQC per DESeq2 vengono inizializzati ma potrebbero rimanere vuoti se nessun metodo di normalizzazione è eseguito.

```groovy
ch_deseq2_pca_multiqc        = Channel.empty()
ch_deseq2_clustering_multiqc = Channel.empty()
```

**Impatto:** MultiQC potrebbe ricevere input vuoti senza dati di normalizzazione.

**Soluzione Raccomandata:**
Aggiungere controllo:
```groovy
// In MultiQC call (linea 825-826)
DESEQ2_TRANSFORM.out.pca.collect().ifEmpty([]),
DESEQ2_TRANSFORM.out.clustering.collect().ifEmpty([])
```
Verificare che i canali siano effettivamente popolati prima di passarli a MultiQC.

---

## ⚠️ BUG MINORI / RISCHI POTENZIALI

### 6. **Regex per Rimozione ID Suffix (Linee 214-221)**

**Codice:**
```groovy
ch_genome_bam
    .map { meta, bam ->
        def new_id = meta.id.replaceAll(/_[^_]+$/, "")
        [meta + [id: new_id], bam]
    }
    .groupTuple(by: [0])
```

**Rischio:** Il regex `/_[^_]+$/` rimuove tutto dopo l'ultimo underscore. Se gli ID non seguono il formato atteso, potrebbero essere raggruppati incorrettamente.

**Raccomandazione:** Aggiungere validazione del formato ID o documentare chiaramente il formato atteso.

---

### 7. **Raccolta Versioni Condizionale (Linea 702)**

**Codice:**
```groovy
ch_versions = ch_versions.mix(ch_normalization_versions)
```

**Rischio:** Se nessun metodo di normalizzazione viene eseguito, `ch_normalization_versions` rimane vuoto, ma questo non causa errori - è corretto ma poco chiaro.

**Raccomandazione:** Aggiungere commento esplicativo.

---

### 8. **Mancanza di Verifica MACS2 Peaks (Linea 433)**

**Codice:**
```groovy
MACS2_CALLPEAK_SINGLE
    .out
    .peak
    .filter { meta, peaks -> peaks.size() > 0 }
    .set { ch_macs2_peaks }
```

**Rischio:** Se TUTTI i campioni hanno 0 peaks, il channel diventa vuoto e i processi downstream potrebbero fallire silenziosamente.

**Raccomandazione:** Aggiungere controllo:
```groovy
ch_macs2_peaks
    .count()
    .subscribe { count ->
        if (count == 0) {
            log.warn "WARNING: No peaks called by MACS2 for any sample!"
        }
    }
```

---

### 9. **DESeq2 Transform con File Flattened (Linea 718)**

**Codice:**
```groovy
DESEQ2_TRANSFORM (
    ch_deseq2_raw_files.flatten(),
    ...
)
```

**Rischio:** `.flatten()` può mescolare i files di diversi metodi di normalizzazione se non gestito correttamente.

**Raccomandazione:** Verificare che DESEQ2_TRANSFORM gestisca correttamente file misti o separare i channels per metodo.

---

## 📊 RIEPILOGO PRIORITÀ

| Priorità | Bug | Impatto | Difficoltà Fix |
|----------|-----|---------|----------------|
| 🔴 Alta | Bug #2: IP-Control Pairing | Potenziale memory overflow | Media |
| 🔴 Alta | Bug #4: Validazione Scaling Factors | Perdita dati silenziosa | Bassa |
| 🟡 Media | Bug #1: BigWig Condizionale | Fallimento se no scaling | Bassa |
| 🟡 Media | Bug #3: Filtri con Null | Errori channel downstream | Bassa |
| 🟡 Media | Bug #8: Verifica Peaks | Fallimento silenzioso | Bassa |
| 🟢 Bassa | Bug #6: Regex ID | Raggruppamento errato | Media |
| 🟢 Bassa | Bug #5: MultiQC Input Vuoti | Input vuoti MultiQC | Bassa |

---

## ✅ PARTI CORRETTE VERIFICATE

1. ✅ **PREPARE_GENOME**: Eseguito correttamente all'inizio
2. ✅ **INPUT_CHECK**: Validazione input funziona
3. ✅ **PICARD_MERGESAMFILES**: Merge funziona dopo groupTuple
4. ✅ **BAM_FILTER_SUBWF**: Applicato dopo mark duplicates
5. ✅ **MACS2_CALLPEAK_MERGED**: Chiamato correttamente su antibody_bam
6. ✅ **Conditional Normalization**: Entrambi i metodi implementati correttamente
7. ✅ **MultiQC**: Raccoglie tutti gli input necessari

---

## 🔧 RACCOMANDAZIONI GENERALI

1. **Aggiungere logging esplicito** per transizioni critiche (es. conteggio campioni prima/dopo filtri)
2. **Implementare failOnMismatch** per operazioni di join critiche
3. **Validare channel counts** in punti chiave per catch errori precoci
4. **Documentare format attesi** per meta.id e sample naming conventions
5. **Aggiungere unit tests** per logica di pairing IP-control

---

## 📝 NOTE

- La pipeline è generalmente ben strutturata
- La maggior parte dei bug sono edge cases che si manifesterebbero con input non standard
- Il codice ha buona modularità ma manca di asserzioni difensive
- La gestione condizionale (with_inputs, skip_*, ecc.) è corretta nella logica ma potrebbe beneficiare di più validazione

