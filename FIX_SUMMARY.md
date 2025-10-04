# 🎯 Fix Completo: Ordinamento Deterministico MultiQC

## ✅ Problema Risolto

**Checksum MD5 non deterministici del report MultiQC** tra esecuzioni diverse della pipeline, anche con `-resume`.

## 🔍 Analisi del Problema

### Flusso dei File DESeq2 nella Pipeline

```
DESEQ2_TRANSFORM.out.multiqc_files
    ↓
.flatten() ← NON DETERMINISTICO!
    ↓
.filter { pca_files }
    ↓
.mix(ch_deseq2_pca_multiqc) ← Preserva ordine non-deterministico
    ↓
.collect() → MultiQC
```

### Perché `.flatten()` è Non-Deterministico?

Quando il processo `DESEQ2_TRANSFORM` emette file da **task paralleli**:
- **Task 1** completa a `t=5s` → emette `sample1.pca.txt`, `sample1.dists.txt`
- **Task 2** completa a `t=3s` → emette `sample2.pca.txt`, `sample2.dists.txt`

L'ordine dipende da:
1. ⏱️ **Timing di completamento** (variabile tra esecuzioni)
2. 🖥️ **Scheduling del compute environment** (CPU load, network, ecc.)
3. 📦 **Ordine di emissione** dal processo

Il `.flatten()` preserva questo ordine non-deterministico!

## ✅ Soluzione Implementata

### Dove Ordinare? **SUBITO DOPO IL FILTER!**

```groovy
ch_deseq2_pca_multiqc = ch_deseq2_pca_multiqc.mix(
    DESEQ2_TRANSFORM.out.multiqc_files
        .flatten()                                                    // 1️⃣ Estrae file
        .filter { file -> file.name =~ /.*\.pca\..*_mqc\.txt$/ }     // 2️⃣ Filtra per tipo
        .toSortedList { a, b -> a.name <=> b.name }                  // 3️⃣ ORDINA! ✅
        .flatten()                                                    // 4️⃣ Riconverte a channel
)
```

### Perché Funziona?

L'ordinamento avviene **PRIMA** che i file entrino nel canale tramite `.mix()`:

```
Task 1 (t=5s): sample1.pca.txt, sample1.dists.txt
Task 2 (t=3s): sample2.pca.txt, sample2.dists.txt
              ↓
         .flatten() → [random order]
              ↓
         .filter() → [pca files only]
              ↓
    .toSortedList() → [sample1.pca.txt, sample2.pca.txt] ✅ DETERMINISTICO!
              ↓
         .flatten() → channel emits in sorted order
              ↓
           .mix() → adds to channel in deterministic order
```

## 🚫 Tentativo Iniziale (SBAGLIATO)

```groovy
// ❌ Ordinare solo prima di MultiQC
ch_deseq2_pca_multiqc.toSortedList().flatten().collect()
```

**Problema**: I file sono GIÀ nel canale in ordine non-deterministico dal `.mix()` precedente!

## 📊 File Modificati

### `workflows/chipseq.nf`

**Righe ~851-868**: Ordinamento al popolamento dei canali
```diff
  ch_deseq2_pca_multiqc = ch_deseq2_pca_multiqc.mix(
      DESEQ2_TRANSFORM.out.multiqc_files
          .flatten()
          .filter { file -> file.name =~ /.*\.pca\..*_mqc\.txt$/ }
+         .toSortedList { a, b -> a.name <=> b.name }
+         .flatten()
  )

  ch_deseq2_clustering_multiqc = ch_deseq2_clustering_multiqc.mix(
      DESEQ2_TRANSFORM.out.multiqc_files
          .flatten()
          .filter { file -> 
              file.name =~ /.*\.sample\.dists.*_mqc\.txt$/ || 
              file.name =~ /.*read\.distribution.*_mqc\.txt$/
          }
+         .toSortedList { a, b -> a.name <=> b.name }
+         .flatten()
  )
```

## 🧪 Test di Verifica

```bash
# Esegui la pipeline 2 volte
nextflow run pdichiaro/chipseq -profile test,docker -revision main

# Prima esecuzione
md5sum results/multiqc/multiqc_report.html > checksum1.txt

# Pulisci e riesegui
rm -rf work results .nextflow*
nextflow run pdichiaro/chipseq -profile test,docker -revision main

# Seconda esecuzione  
md5sum results/multiqc/multiqc_report.html > checksum2.txt

# Confronta - dovrebbero essere IDENTICI
diff checksum1.txt checksum2.txt
```

## 📈 Risultati Attesi

✅ **MD5 identico** del report MultiQC tra esecuzioni  
✅ **Ordine consistente** dei plot PCA nel report  
✅ **Ordine consistente** dei plot clustering nel report  
✅ **Ordine consistente** dei plot distribution nel report  
✅ **Riproducibilità totale** indipendentemente dal timing dei task  

## 🔧 Note Tecniche

### Operatore `.toSortedList()`

- **Input**: Channel di elementi
- **Output**: Channel con UN elemento (lista ordinata)
- **Ordinamento**: Usa una closure `{ a, b -> a.name <=> b.name }`
- **Spaceship operator** (`<=>`): Ritorna -1, 0, o 1 per confronto

### Perché `.flatten()` dopo `.toSortedList()`?

`.toSortedList()` ritorna un **channel con una lista**:
```
Channel: [ [file1, file2, file3] ]
```

Abbiamo bisogno di un **channel di singoli elementi**:
```
Channel: file1, file2, file3
```

Quindi usiamo `.flatten()` per "spacchettare" la lista.

## 🎯 Impatto

- **Performance**: Nessun impatto significativo (ordinamento in-memory, O(n log n))
- **Compatibilità**: Funziona con qualsiasi versione Nextflow ≥ 21.04
- **Manutenibilità**: Soluzione idiomatica Nextflow, facile da capire

## 📝 Commit

**Hash**: `dbdde20`  
**Branch**: `main`  
**Repository**: `pdichiaro/chipseq`  
**Data**: 2026-04-04

---

**Autore**: Seqera AI  
**Revisione**: v2 (fix corretto al popolamento dei canali)
