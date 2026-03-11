# 🎯 Primary vs Secondary Alignments: Definitive Guide

## ❓ **La Tua Domanda**

> "keep_multi_map = true: Mantiene multi-mapper (skip -q 1) come gestiamo primary and secondary alignment?"

## ✅ **Risposta Breve**

**SEMPRE filtriamo secondary/supplementary alignments (`-F 0x0100 -F 0x0800`)**, **indipendentemente** da `keep_multi_map`!

- **keep_multi_map = false**: Rimuove primary con MAPQ=0
- **keep_multi_map = true**: **Mantiene SOLO primary** con MAPQ=0 (random assignment)
- **Secondary alignments**: SEMPRE rimosse in entrambi i casi

---

## 📚 **Background: SAM Flags**

```bash
# SAM Flags per alignments
0x0100 (256)  = Secondary alignment
0x0800 (2048) = Supplementary alignment

# Un read può avere:
- 1 primary alignment   (no flags)
- N secondary alignments (flag 0x0100)
- M supplementary (split reads, flag 0x0800)
```

---

## 🔬 **Bowtie2 Behavior**

### **Scenario A: NO `-k` flag (default)**

```bash
bowtie2 -x genome -1 r1.fq -2 r2.fq

Output per read:
- 1 primary alignment (best location)
- MAPQ = 0 if multi-mapper (ambiguous)
- MAPQ > 0 if unique mapper
```

**Esempio:**
```
READ_001 → 3 locations (chr1:100, chr2:200, chr3:300)
Bowtie2 picks randomly: chr1:100 (MAPQ=0, no secondary flag)
```

### **Scenario B: WITH `-k 100` flag**

```bash
bowtie2 -x genome -1 r1.fq -2 r2.fq -k 100

Output per read:
- 1 primary alignment (flag=0, MAPQ=0)
- Up to 99 secondary alignments (flag=0x0100, MAPQ=0)
```

**Esempio:**
```
READ_001 → 3 locations (chr1:100, chr2:200, chr3:300)

Bowtie2 reports:
├─ chr1:100  flag=0      MAPQ=0  (PRIMARY)
├─ chr2:200  flag=0x0100 MAPQ=0  (SECONDARY)
└─ chr3:300  flag=0x0100 MAPQ=0  (SECONDARY)
```

---

## 🔧 **BAM_FILTER Implementation**

### **Step 1: Remove Secondary/Supplementary (ALWAYS)**

```bash
samtools view \
    -F 0x0100 \  # ← Exclude secondary alignments
    -F 0x0800 \  # ← Exclude supplementary alignments
    -F 0x004 \   # Exclude unmapped reads
    -F 0x0008 \  # Exclude unmapped mates (PE)
    -f 0x001 \   # Require paired flag (PE)
    -f 0x002 \   # Require proper pair (PE)
    -F 0x0400 \  # Exclude duplicates (if keep_dups=false)
    -b input.bam > filter1.bam
```

**Result dopo Step 1:**
- ✅ Solo primary alignments rimangono
- ✅ Secondary/supplementary completamente rimossi
- ⚠️ Include primary con MAPQ=0 (multi-mapper)

### **Step 2a: Remove Multi-mappers (keep_multi_map=false)**

```bash
samtools view -q 1 -h filter1.bam | \  # ← MAPQ >= 1 only
    awk 'insert_size_filter' | \
    samtools view -b > filter2.bam
```

**Result:**
- ✅ Solo uniquely mapped reads (MAPQ >= 1)
- ❌ Rimuove primary con MAPQ=0

### **Step 2b: Keep Multi-mappers (keep_multi_map=true)**

```bash
samtools view -h filter1.bam | \  # ← NO -q flag
    awk 'insert_size_filter' | \
    samtools view -b > filter2.bam
```

**Result:**
- ✅ Include uniquely mapped (MAPQ >= 1)
- ✅ Include primary con MAPQ=0 (random assignment)
- ❌ NO secondary alignments (già filtrate in Step 1)

---

## 📊 **Concrete Example**

### **Input BAM (Bowtie2 -k 100):**

```
READ_001: chr1:100  flag=0      MAPQ=0   (PRIMARY)
READ_001: chr2:200  flag=0x0100 MAPQ=0   (SECONDARY)
READ_001: chr3:300  flag=0x0100 MAPQ=0   (SECONDARY)
READ_002: chr5:500  flag=0      MAPQ=42  (PRIMARY, unique)
```

### **After Step 1 (remove secondary):**

```
READ_001: chr1:100  flag=0  MAPQ=0   (PRIMARY only)
READ_002: chr5:500  flag=0  MAPQ=42  (PRIMARY only)
```

### **After Step 2a (keep_multi_map=false):**

```
READ_002: chr5:500  flag=0  MAPQ=42  (Unique mapper only)
```

### **After Step 2b (keep_multi_map=true):**

```
READ_001: chr1:100  flag=0  MAPQ=0   (PRIMARY, random assignment)
READ_002: chr5:500  flag=0  MAPQ=42  (Unique mapper)
```

---

## 🎯 **Key Insights**

### ✅ **Cosa NON cambia con keep_multi_map:**
1. Secondary alignments sono **SEMPRE** filtrate (`-F 0x0100`)
2. Supplementary alignments sono **SEMPRE** filtrate (`-F 0x0800`)
3. Solo **1 alignment per read** passa downstream

### ✅ **Cosa CAMBIA con keep_multi_map:**
1. **false**: Rimuove primary con MAPQ=0 (via `-q 1`)
2. **true**: Mantiene primary con MAPQ=0 (random assignment da multi-mapper)

### 🎯 **Risultato finale:**
- **Sempre 1 alignment per read max**
- **Mai multiple alignment dello stesso read**
- **keep_multi_map controlla solo se accettare MAPQ=0**

---

## 💡 **Perché è importante?**

### **Scenario problematico (se NON filtramo secondary):**

```bash
# Senza -F 0x0100
READ_001: chr1:100  MAPQ=0  (primary)
READ_001: chr2:200  MAPQ=0  (secondary)
READ_001: chr3:300  MAPQ=0  (secondary)

Peak calling:
- chr1:100 vede 1 read (o 3?)
- chr2:200 vede 1 read (o 3?)
- chr3:300 vede 1 read (o 3?)

→ Inflazione artificiale del segnale!
→ False positive peaks!
```

### **Scenario corretto (con -F 0x0100):**

```bash
# Con -F 0x0100
READ_001: chr1:100  MAPQ=0  (primary only)

Peak calling:
- chr1:100 vede 1 read (random assignment)
- chr2:200 vede 0 reads
- chr3:300 vede 0 reads

→ Nessuna inflazione
→ Conservative approach
```

---

## 📋 **Implementation nf-core vs pdichiaro**

### **nf-core/chipseq:**
```bash
samtools view -F 0x0100 -q 1 ...  # Remove secondary + multi-mapper
```

### **pdichiaro/chipseq:**
```bash
samtools view -F 0x0100 -F 0x0800 -q 1 ...  # Remove secondary + supplementary + multi-mapper
```

**Differenza:**
- ✅ **pdichiaro più strict**: Rimuove anche supplementary (split reads)
- ✅ **Entrambi rimuovono secondary**: Comportamento identico per multi-mapper

---

## ✅ **Conclusione**

### **Risposta alla tua domanda:**

> **"keep_multi_map = true: come gestiamo primary and secondary alignment?"**

**Risposta:**
1. **Secondary alignments**: SEMPRE rimosse via `-F 0x0100 -F 0x0800`
2. **Primary alignments**: Controllate da `keep_multi_map`
   - `false`: Solo MAPQ >= 1 (unique mappers)
   - `true`: Include MAPQ = 0 (random assignment da multi-mapper)
3. **Risultato**: SEMPRE 1 alignment max per read, MAI duplicati

### **Implementazione corretta:**

```bash
# SEMPRE questo filtro (indipendente da keep_multi_map)
def base_filter = '-F 0x0100 -F 0x0800'  # Exclude secondary + supplementary

# Poi aggiungi altri filtri
def filter_params = meta.single_end ? 
    "${base_filter} -F 0x004" : 
    "${base_filter} -F 0x004 -F 0x0008 -f 0x001 -f 0x002"
```

**Questa implementazione è già nel tuo codice!** ✅

---

## 🔍 **Verifica Pratica**

Per verificare che funzioni correttamente:

```bash
# Count alignments per read name
samtools view filter2.bam | cut -f1 | sort | uniq -c | sort -rn | head

# Output atteso:
# 1 READ_001
# 1 READ_002
# 1 READ_003
# ...

# Se vedi numeri > 1, hai un problema con i filtri!
```

---

## 🎉 **Bottom Line**

**La tua pipeline è corretta!** 

- ✅ Secondary alignments sempre filtrate
- ✅ keep_multi_map controlla solo MAPQ threshold
- ✅ Mai duplicati downstream
- ✅ Comportamento allineato con nf-core (+ supplementary removal!)

**Non serve nessuna modifica ulteriore.** 🎯
