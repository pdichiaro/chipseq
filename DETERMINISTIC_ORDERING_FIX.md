# Fix per Ordinamento Deterministico dei File MultiQC

## 🎯 Problema Identificato

I file passati a MultiQC dai processi DESeq2 non avevano un ordine deterministico, causando:
- **MD5 checksum diversi** del report MultiQC tra esecuzioni
- **Ordine variabile** delle sezioni nel report
- **Non riproducibilità** anche con `-resume`

## 🔍 Causa Radice

### File: `workflows/chipseq.nf` (righe ~850-865)

I canali `ch_deseq2_pca_multiqc` e `ch_deseq2_clustering_multiqc` venivano popolati con:

```groovy
ch_deseq2_pca_multiqc = ch_deseq2_pca_multiqc.mix(
    DESEQ2_TRANSFORM.out.multiqc_files
        .flatten()
        .filter { file -> file.name =~ /.*\.pca\..*_mqc\.txt$/ }
)
```

Il problema era che `.flatten()` **non garantisce ordine deterministico** quando i file provengono da:
1. **Task paralleli** del processo DESEQ2_TRANSFORM (ordine di completamento variabile)
2. **Emissioni multiple** dal processo (timing non deterministico)
3. **Mix di canali** che preserva l'ordine di arrivo originale

Anche se i file venivano poi passati a MultiQC con `.collect()`, l'ordine era già compromesso **al momento del popolamento dei canali**.

## ✅ Soluzione Implementata

Ordinamento esplicito **al momento del popolamento dei canali**:

```groovy
ch_deseq2_pca_multiqc = ch_deseq2_pca_multiqc.mix(
    DESEQ2_TRANSFORM.out.multiqc_files
        .flatten()
        .filter { file -> file.name =~ /.*\.pca\..*_mqc\.txt$/ }
        .toSortedList { a, b -> a.name <=> b.name }
        .flatten()
)

ch_deseq2_clustering_multiqc = ch_deseq2_clustering_multiqc.mix(
    DESEQ2_TRANSFORM.out.multiqc_files
        .flatten()
        .filter { file -> 
            file.name =~ /.*\.sample\.dists.*_mqc\.txt$/ || 
            file.name =~ /.*read\.distribution.*_mqc\.txt$/
        }
        .toSortedList { a, b -> a.name <=> b.name }
        .flatten()
)
```

### Come Funziona

1. **`.flatten()`** - Estrae i singoli file dall'output del processo
2. **`.filter { ... }`** - Seleziona solo i file del tipo corretto (PCA o clustering)
3. **`.toSortedList { a, b -> a.name <=> b.name }`** 
   - **KEY STEP**: Raccoglie tutti i file filtrati e li ordina alfabeticamente
   - Garantisce che l'ordine sia deterministico **prima** del mix
4. **`.flatten()`** - Riconverte la lista ordinata in un channel di singoli elementi
5. **`.mix()`** - Aggiunge al canale esistente mantenendo l'ordine

Quando poi i file arrivano a MultiQC con `.collect()`, l'ordine è già deterministico.

## 📊 Risultato Atteso

- ✅ MD5 checksum identico del report MultiQC tra esecuzioni
- ✅ Ordine consistente delle sezioni nel report
- ✅ Riproducibilità totale del risultato
- ✅ Nessun impatto sulle prestazioni (ordinamento marginale)

## 🧪 Test di Verifica

```bash
# Esegui la pipeline 2 volte
nextflow run nf-core/chipseq -profile test,docker

# Calcola MD5 del report MultiQC dalla prima esecuzione
md5sum results/multiqc/multiqc_report.html > checksum1.txt

# Pulisci e riesegui
rm -rf work results .nextflow*
nextflow run nf-core/chipseq -profile test,docker

# Calcola MD5 della seconda esecuzione
md5sum results/multiqc/multiqc_report.html > checksum2.txt

# Confronta
diff checksum1.txt checksum2.txt
# Output atteso: nessuna differenza
```

## 📝 Note Tecniche

### Perché toSortedList?
- **Operatore Nextflow nativo** per ordinamento deterministico
- **Efficiente**: ordinamento in-memory
- **Type-safe**: preserva i metadati dei file

### Perché ordinare al popolamento invece che prima di MultiQC?

**Tentativo iniziale (SBAGLIATO)**:
```groovy
// Ordinare solo prima di passare a MultiQC
ch_deseq2_pca_multiqc.toSortedList { ... }.flatten().collect()
```

**Problema**: I canali sono già popolati con ordine non-deterministico dal `.mix()`, quindi ordinare alla fine non risolve se i file arrivano in ordine diverso tra esecuzioni.

**Soluzione corretta**: Ordinare **subito dopo il filter**, prima del `.mix()`, così l'ordine è deterministico dal momento in cui i file entrano nel canale.

### Impatto su Altri Canali MultiQC

Gli altri canali MultiQC nella pipeline usano `.collect{it[1]}` che estrae solo il file dalla tupla `[meta, file]`. Questi **potrebbero avere lo stesso problema** se l'ordine è importante.

Esempio di altri canali che potrebbero beneficiare dello stesso fix:
```groovy
ch_fastqc_raw_multiqc.collect{it[1]}.ifEmpty([])
ch_fastqc_trim_multiqc.collect{it[1]}.ifEmpty([])
```

Se si nota non-determinismo anche in queste sezioni, applicare lo stesso pattern:
```groovy
ch_fastqc_raw_multiqc.toSortedList { a, b -> a[1].name <=> b[1].name }.flatten().collect{it[1]}.ifEmpty([])
```

## 🔗 Riferimenti

- Nextflow Operator Documentation: https://www.nextflow.io/docs/latest/operator.html#tosortedlist
- nf-core MultiQC Integration: https://nf-co.re/docs/usage/configuration#multiqc
- Issue GitHub correlato: (da aggiungere se necessario)

---

**Data Fix**: 2025-01-XX  
**Autore**: Seqera AI  
**Versione Pipeline**: chipseq (branch: seqera-ai/20250128-095052-extend-samplesheet-normalization)
