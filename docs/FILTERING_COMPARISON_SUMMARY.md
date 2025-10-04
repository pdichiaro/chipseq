# Filtering Comparison: nf-core vs pdichiaro - SINTESI

## ✅ Risposta Breve

**SÌ, nf-core/chipseq usa un approccio 2-step per il filtering paired-end.**

Entrambi i pipeline applicano i filtri in passaggi sequenziali, ma con strumenti diversi:

| Pipeline | STEP 1 | STEP 2 | STEP 3 |
|----------|--------|--------|--------|
| **nf-core** | samtools view (flags + MAPQ + blacklist) | bamtools filter (insert size + mismatches) | Python orphan removal |
| **pdichiaro** | samtools view (flags + blacklist) | samtools + awk (MAPQ + insert size) | - |

---

## 🔑 Differenze Chiave

### 1️⃣ SAM Flags Filtering

| Flag | Descrizione | nf-core | pdichiaro |
|------|------------|---------|-----------|
| `-f 0x0002` | Proper pair | ❌ No | ✅ Yes |
| `-F 0x0100` | Secondary alignment | ❌ No | ✅ Yes |
| `-F 0x0800` | Supplementary | ❌ No | ✅ Yes |

**→ pdichiaro è PIÙ STRINGENTE sui SAM flags**

---

### 2️⃣ Insert Size Range

| Pipeline | Range | Scopo |
|----------|-------|-------|
| **nf-core** | -2000 to +2000 bp | Range ampio (include anche nucleosome-bound) |
| **pdichiaro** | 0 to 500 bp | Specifico per nucleosome-free regions |

**→ pdichiaro è PIÙ SPECIFICO per ChIP-seq standard**

---

### 3️⃣ Orphan Removal

| Pipeline | Metodo | Robustezza |
|----------|--------|------------|
| **nf-core** | Script Python dedicato (bampe_rm_orphan.py) | ⭐⭐⭐ Alta - rimuove esplicitamente singleton reads |
| **pdichiaro** | Flag `-f 0x0002` (proper pair) | ⭐⭐ Media - rimozione implicita via flag |

**⚠️ POTENZIALE ISSUE IN pdichiaro:**
- Il flag `0x0002` (proper pair) potrebbe **non catturare TUTTI** i singleton reads
- Se un aligner marca una read come "paired" (0x0001) ma non "proper pair" (0x0002), 
  alcuni singleton potrebbero passare
- **nf-core è più robusto** con il check esplicito via Python script

---

### 4️⃣ Mismatch Filter (NM tag)

| Pipeline | Applicato | Threshold |
|----------|-----------|-----------|
| **nf-core** | ✅ Yes | NM <= 4 mismatches |
| **pdichiaro** | ❌ No | N/A |

**→ nf-core filtra reads con troppi mismatches**

---

## 🎯 Vantaggi Comparati

### nf-core/chipseq ✅

- ✅ **Orphan removal robusto** (Python script dedicato)
- ✅ **Mismatch filter** (NM <= 4)
- ✅ **Insert size flessibile** (configurabile via JSON)
- ❌ Complessità alta (3 tool: samtools + bamtools + Python)
- ❌ Performance inferiore (name-sort + Python processing)

### pdichiaro/chipseq ✅

- ✅ **Semplicità** (solo samtools + awk)
- ✅ **Performance** (2 pass veloci, no sorting intermedio)
- ✅ **Più stringente su flags** (filtra secondary/supplementary)
- ✅ **Insert size specifico** (0-500bp ottimale per ChIP-seq)
- ❌ Orphan removal implicito (potrebbe non catturare tutti i singleton)
- ❌ No mismatch filter

---

## 📌 Raccomandazioni per pdichiaro/chipseq

### 🟢 OPZIONE 1: Mantenere approccio attuale + orphan check
**→ Raccomandato per la maggior parte dei casi**

Aggiungere un orphan removal esplicito DOPO il filtering:

```bash
# Dopo PASS 2, prima del sort finale
# 1. Name-sort
samtools sort -n sample.filter2.bam -o sample.filter2.nsort.bam

# 2. Remove orphans con samtools fixmate
samtools fixmate -m sample.filter2.nsort.bam - | \
  samtools view -b -f 0x0001 -F 0x0004 -F 0x0008 > sample.filter2.no_orphans.bam

# 3. Re-sort by coordinate
samtools sort sample.filter2.no_orphans.bam -o sample.filter2.sorted.bam
```

**Vantaggi:**
- ✅ Mantiene semplicità (solo samtools)
- ✅ Risolve il problema degli orphan reads
- ✅ Performance ancora buona

**Svantaggi:**
- ⚠️ Richiede un name-sort intermedio (overhead)

---

### 🟡 OPZIONE 2: Validare che orphan removal sia già efficace

Testare se il flag `-f 0x0002` (proper pair) già rimuove tutti gli orphan:

```bash
# Test su un BAM sample
# 1. Conta singleton reads nel BAM pre-filtered
samtools view -c -f 0x0001 -F 0x0002 sample.mkD.bam

# 2. Conta singleton reads nel BAM post-filtered
samtools view -c -f 0x0001 -F 0x0002 sample.filter2.bam

# Se il count in (2) è 0, il filtering attuale è già efficace!
```

**Se il test mostra che `-f 0x0002` rimuove tutti gli orphan:**
- ✅ Nessuna modifica necessaria
- ✅ Approccio attuale già ottimale

**Se il test mostra orphan residui:**
- ⚠️ Applicare OPZIONE 1

---

### 🔵 OPZIONE 3: Aggiungere mismatch filter (opzionale)

Solo se il tuo caso d'uso richiede filtri molto stringenti:

```bash
# In PASS 2, aggiungere filtro NM tag
samtools view -q 1 -h sample.filter1.bam | \
  awk -v max="500" -v nm_max="4" \
    'BEGIN{OFS="\t"} 
     /^@/ {print; next}
     {
       nm = 999
       for(i=12; i<=NF; i++) {
         if($i ~ /^NM:i:/) {
           sub(/NM:i:/, "", $i)
           nm = $i
           break
         }
       }
       if((($9>=0?$9:-$9)<=max) && (nm<=nm_max)) print
     }' | \
  samtools view -b > sample.filter2.bam
```

---

## 📊 Decision Matrix

| Scenario | Raccomandazione |
|----------|----------------|
| **Standard ChIP-seq, priorità performance** | Mantenere approccio attuale + test orphan (OPZIONE 2) |
| **ChIP-seq robusto, priorità qualità** | Aggiungere orphan removal esplicito (OPZIONE 1) |
| **ATAC-seq o DNase-seq (nucleosome-free)** | Approccio attuale OTTIMO (insert size 0-500bp) |
| **Broad ChIP-seq (H3K27me3, etc.)** | Considerare insert size range più ampio (come nf-core) |
| **Low-quality samples** | OPZIONE 1 + OPZIONE 3 (orphan removal + mismatch filter) |

---

## 🎓 Conclusione

**Il tuo approccio 2-pass è concettualmente identico a nf-core**, solo con:
- ✅ Strumenti più semplici (samtools vs samtools+bamtools)
- ✅ Maggiore stringenza su SAM flags
- ⚠️ Potenziale gap sull'orphan removal (da testare/validare)

**Next step consigliato:**
1. Eseguire il test OPZIONE 2 per verificare se `-f 0x0002` rimuove già tutti gli orphan
2. Se il test fallisce → implementare OPZIONE 1
3. Se il test passa → documentare che l'approccio attuale è già robusto

---

## 📚 Riferimenti

- **Documento completo**: `NFCORE_FILTERING_COMPARISON.md`
- **nf-core/chipseq**: https://github.com/nf-core/chipseq
- **Modulo bamtools_filter**: `nf-core/chipseq/modules/local/bamtools_filter.nf`
- **Script orphan removal**: `nf-core/chipseq/bin/bampe_rm_orphan.py`
