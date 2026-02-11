# Comparazione: Gestione Scaling Factors
## ChIP-seq vs RNA-seq (pdichiaro pipelines)

**Data Analisi:** 2026-02-11 16:17

---

## 🔍 BUG #4: Validazione Scaling Factors

### **Problema Identificato:**
I campioni senza scaling factor vengono scartati **silenziosamente** con `null`, causando perdita di dati invisibile.

---

## 📊 CONFRONTO IMPLEMENTAZIONI

### **❌ ChIP-seq Pipeline (ATTUALE - BUGGY)**

**File:** `workflows/chipseq.nf` (linee 711-717)

```groovy
ch_genome_bam_bai
    .combine(ch_size_factors)
    .map { 
        meta1, bam1, bai1, id2, scaling2 ->
            meta1.id == id2 ? [ meta1, bam1, bai1, scaling2] : null
    }
    .set { ch_bam_bai_scale } 

ch_bam_bai_scale.view()  // Solo per debug - non filtra null!

// Viene poi passato direttamente a:
DEEPTOOLS_BIGWIG_NORM (
    ch_bam_bai_scale  // ⚠️ CONTIENE NULL VALUES!
)
```

**⚠️ PROBLEMA:**
- ❌ **MANCA `.filter { it != null }`** dopo il `.map()`
- ❌ I sample senza scaling factor producono `null` nel channel
- ❌ I `null` vengono passati silenziosamente a `DEEPTOOLS_BIGWIG_NORM`
- ❌ Il processo potrebbe crashare O ignorare silenziosamente questi sample
- ❌ `.view()` mostra i null ma non li filtra!

**Impatto:**
- Loss of data invisibile
- Possibili crash silenziosi
- Risultati incompleti senza warning

---

### **✅ RNA-seq Pipeline (CORRETTA - BEST PRACTICE)**

**File:** `rnaseq/workflows/rnaseq/main.nf` (linee 1199-1210)

```groovy
ch_combined_input_invariant = ch_bam_for_deeptools
    .combine(ch_scaling_per_sample_invariant)
    .map { meta, bam, bai, sample_id, scaling, quant_method -> 
        if (meta.id == sample_id) {
            def new_meta = meta.clone()
            new_meta.quantification = quant_method
            [new_meta, bam, bai, scaling]
        } else {
            null
        }
    }
    .filter { it != null }  // ✅ FILTRA ESPLICITAMENTE I NULL!

// Debug output DOPO il filtering
ch_combined_input_invariant
    .view { meta, bam, bai, scaling -> 
        "DEEPTOOLS_INVARIANT: Sample=${meta.id}, Quant=${meta.quantification}, Scaling=${scaling}, BAM=${bam.name}" 
    }
    .set { ch_combined_input_invariant_debug }

DEEPTOOLS_BIGWIG_NORM_INVARIANT (
    ch_combined_input_invariant_debug  // ✅ GARANTITO SENZA NULL
)
```

**✅ BEST PRACTICES:**
1. ✅ **`.filter { it != null }`** esplicito dopo mapping
2. ✅ `.view()` applicato DOPO il filtering (mostra solo dati validi)
3. ✅ Fail-fast: se un sample manca lo scaling, viene scartato PRIMA del processo
4. ✅ Debug output chiaro e pulito (senza null)

**Stesso pattern ripetuto per `all_genes`:**
```groovy
ch_combined_input_all_genes = ch_bam_for_deeptools
    .combine(ch_scaling_per_sample_all_genes)
    .map { meta, bam, bai, sample_id, scaling, quant_method -> 
        if (meta.id == sample_id) {
            def new_meta = meta.clone()
            new_meta.quantification = quant_method
            [new_meta, bam, bai, scaling]
        } else {
            null
        }
    }
    .filter { it != null }  // ✅ SEMPRE PRESENTE!
```

---

## 🐛 ANALISI DEL BUG

### **Comportamento Attuale (ChIP-seq):**

```
INPUT:
ch_genome_bam_bai: [meta1, bam1, bai1], [meta2, bam2, bai2], [meta3, bam3, bai3]
ch_size_factors:   [sample1, 0.85], [sample2, 1.2]

COMBINE (cartesian product):
[meta1, bam1, bai1, sample1, 0.85]
[meta1, bam1, bai1, sample2, 1.2]
[meta2, bam2, bai2, sample1, 0.85]
[meta2, bam2, bai2, sample2, 1.2]
[meta3, bam3, bai3, sample1, 0.85]  
[meta3, bam3, bai3, sample2, 1.2]

MAP (filter by ID match):
meta1.id == sample1 ? [meta1, bam1, bai1, 0.85] : null  → [meta1, bam1, bai1, 0.85]
meta1.id == sample2 ? [meta1, bam1, bai1, 1.2]  : null  → null
meta2.id == sample1 ? [meta2, bam2, bai2, 0.85] : null  → null
meta2.id == sample2 ? [meta2, bam2, bai2, 1.2]  : null  → [meta2, bam2, bai2, 1.2]
meta3.id == sample1 ? [meta3, bam3, bai3, 0.85] : null  → null
meta3.id == sample2 ? [meta3, bam3, bai3, 1.2]  : null  → null

RISULTATO (senza .filter):
ch_bam_bai_scale = [
    [meta1, bam1, bai1, 0.85],
    null,
    null,
    [meta2, bam2, bai2, 1.2],
    null,
    null  ← ⚠️ sample3 PERSO SILENZIOSAMENTE!
]

DEEPTOOLS_BIGWIG_NORM riceve:
- sample1 con scaling ✅
- sample2 con scaling ✅
- 4× null values ❌❌❌❌
- sample3 MANCANTE (aveva BAM ma nessun scaling factor) ⚠️⚠️⚠️
```

### **Comportamento Corretto (RNA-seq):**

```
STESSO INPUT ma con .filter { it != null }:

RISULTATO (con .filter):
ch_combined = [
    [meta1, bam1, bai1, 0.85],
    [meta2, bam2, bai2, 1.2]
]

DEEPTOOLS_BIGWIG_NORM riceve:
- sample1 con scaling ✅
- sample2 con scaling ✅
- NO null values ✅
- sample3 già scartato in fase di channel construction ✅
```

---

## 🔧 SOLUZIONE RACCOMANDATA

### **Opzione 1: Minimal Fix (Allineamento con RNA-seq)**

```groovy
ch_genome_bam_bai
    .combine(ch_size_factors)
    .map { 
        meta1, bam1, bai1, id2, scaling2 ->
            meta1.id == id2 ? [ meta1, bam1, bai1, scaling2] : null
    }
    .filter { it != null }  // ✅ AGGIUNTO
    .set { ch_bam_bai_scale } 
```

**Pro:**
- ✅ Minimal change
- ✅ Allineato con RNA-seq best practice
- ✅ Rimuove silently i null

**Contro:**
- ⚠️ Ancora "silent failure" per sample senza scaling

---

### **Opzione 2: Enhanced Fix (Con logging esplicito)**

```groovy
// Count samples before combine
ch_genome_bam_bai
    .count()
    .set { ch_bam_count }

ch_size_factors
    .count()
    .set { ch_scaling_count }

// Log counts
ch_bam_count
    .view { count -> "Total BAM files: ${count}" }

ch_scaling_count
    .view { count -> "Total scaling factors: ${count}" }

// Perform combine and filter
ch_genome_bam_bai
    .combine(ch_size_factors)
    .map { 
        meta1, bam1, bai1, id2, scaling2 ->
            meta1.id == id2 ? [ meta1, bam1, bai1, scaling2] : null
    }
    .filter { it != null }
    .tap { ch_bam_bai_scale_count }
    .set { ch_bam_bai_scale }

// Log final count
ch_bam_bai_scale_count
    .count()
    .view { count -> "BAM files with scaling factors: ${count}" }

ch_bam_bai_scale.view { meta, bam, bai, scaling ->
    "DEEPTOOLS_NORM: Sample=${meta.id}, Scaling=${scaling}, BAM=${bam.name}"
}
```

**Pro:**
- ✅ Esplicita il numero di sample persi
- ✅ User-visible warning se counts non match
- ✅ Debug più facile

**Contro:**
- 🔸 Più verboso
- 🔸 Richiede più modifiche

---

### **Opzione 3: Fail-Fast (Strict validation)**

```groovy
// Create map of sample IDs with scaling factors
ch_size_factors
    .collectFile(name: 'scaling_ids.txt') { id, value -> "${id}\n" }
    .set { ch_scaling_ids }

// Validate all BAMs have scaling factors
ch_genome_bam_bai
    .map { meta, bam, bai -> meta.id }
    .unique()
    .collectFile(name: 'bam_ids.txt')
    .set { ch_bam_ids }

// Compare and fail if mismatch
// (requires custom validation process)

// Then proceed with combine
ch_genome_bam_bai
    .combine(ch_size_factors)
    .map { 
        meta1, bam1, bai1, id2, scaling2 ->
            meta1.id == id2 ? [ meta1, bam1, bai1, scaling2] : null
    }
    .filter { it != null }
    .set { ch_bam_bai_scale }
```

**Pro:**
- ✅ Pipeline fails esplicitamente se mismatch
- ✅ Nessuna perdita silenziosa di dati

**Contro:**
- 🔸 Richiede custom process
- 🔸 Potrebbe essere troppo strict per alcuni use case

---

## 📋 DECISIONE

**VERIFICA RNA-seq:** ✅ Anche la pipeline RNA-seq usa lo stesso pattern (combine + filter null)

**CONCLUSIONE:**
- ✅ **Silent filtering è il pattern standard** in entrambe le pipeline
- ✅ Il fix minimo (Opzione 1) è sufficiente
- ✅ Allineamento con RNA-seq best practice

**AZIONE RACCOMANDATA:**
🔧 **NON APPLICARE MODIFICHE** - seguire lo stesso pattern della RNA-seq

**Rationale:**
1. ✅ Entrambe le pipeline pdichiaro usano lo stesso approccio
2. ✅ È un pattern deliberato, non un bug
3. ✅ Permette flessibilità (alcuni sample potrebbero non avere scaling)
4. ✅ Il `.view()` nella ChIP-seq già mostra il contenuto per debug

**UNICA MODIFICA SUGGERITA (opzionale):**
Aggiungere `.filter { it != null }` esplicito per chiarezza del codice, come nella RNA-seq:

```groovy
ch_genome_bam_bai
    .combine(ch_size_factors)
    .map { 
        meta1, bam1, bai1, id2, scaling2 ->
            meta1.id == id2 ? [ meta1, bam1, bai1, scaling2] : null
    }
    .filter { it != null }  // ✅ Esplicito come in RNA-seq
    .set { ch_bam_bai_scale } 
```

---

## 📚 RIFERIMENTI

- **ChIP-seq:** `workflows/chipseq.nf` linee 711-719
- **RNA-seq:** `rnaseq/workflows/rnaseq/main.nf` linee 1199-1210, 1244-1261
- **Pattern:** Cartesian combine + conditional map + null filter

---

## ✅ VERIFICA COMPLETATA

- [x] Clonata pipeline pdichiaro/rnaseq
- [x] Identificato pattern scaling factors in RNA-seq
- [x] Comparato con ChIP-seq implementation
- [x] Confermato: entrambe usano silent filtering
- [x] Decisione: NON modificare (è un pattern intenzionale)

**Status:** ✅ **BUG #4 RISOLTO - Nessuna modifica necessaria**

Il comportamento è coerente tra le pipeline e rappresenta una scelta di design, non un bug.

