# Confronto Filtering: nf-core/chipseq vs pdichiaro/chipseq

## Sintesi Esecutiva

**✅ SÌ, nf-core/chipseq usa un approccio 2-step simile per il filtering paired-end!**

La differenza principale è che **nf-core** usa una combinazione di:
1. **samtools view** (STEP 1) → applica flag-based filters + blacklist + MAPQ
2. **bamtools filter** (STEP 2) → applica insert size filter + mismatch filter
3. **BAM_REMOVE_ORPHANS** (STEP 3) → rimuove singleton reads (orphans)

Mentre **pdichiaro/chipseq** usa solo **samtools** in 2 passaggi:
1. **samtools view** (PASS 1) → flag-based filters + blacklist
2. **samtools view + awk** (PASS 2) → MAPQ + insert size

---

## Confronto Dettagliato

### 🔧 TOOL UTILIZZATI

| Aspetto | nf-core/chipseq | pdichiaro/chipseq |
|---------|----------------|------------------|
| **Tool principali** | samtools + bamtools + Python | samtools + awk |
| **Complexity** | Alta (3 tool) | Bassa (2 tool) |
| **Dependencies** | samtools, bamtools, pysam | samtools, awk |
| **Custom scripts** | bampe_rm_orphan.py | Nessuno |

---

## 📋 FLUSSO DI FILTERING PAIRED-END

### nf-core/chipseq

```
INPUT: sample.mkD.bam (post-MarkDuplicates)
  │
  ▼
┌─────────────────────────────────────────────────────────────┐
│ STEP 1: BAMTOOLS_FILTER (samtools view)                     │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                             │
│ samtools view -b \                                          │
│   -F 0x004               # Remove unmapped                 │
│   -F 0x0008              # Remove mate unmapped            │
│   -f 0x001               # Keep paired                     │
│   -F 0x0400              # Remove duplicates (if !keep_dups)│
│   -q 1                   # MAPQ >= 1 (if !keep_multi_map)  │
│   -L blacklist.bed       # Keep NON-blacklist              │
│   sample.mkD.bam | \                                        │
│                                                             │
│ bamtools filter -script bamtools_filter_pe.json             │
│                                                             │
│ Output: sample.mLb.flT.sorted.bam                           │
└─────────────────────────────────────────────────────────────┘
  │
  ▼
bamtools_filter_pe.json filters:
  • insertSize >= -2000
  • insertSize <= 2000  
  • NM tag (mismatches) <= 4
  │
  ▼
┌─────────────────────────────────────────────────────────────┐
│ STEP 2: SAMTOOLS_SORT (name-sorted for orphan removal)      │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                             │
│ samtools sort -n sample.mLb.flT.sorted.bam                  │
│                                                             │
│ Output: sample.name.sorted.bam                              │
└─────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────┐
│ STEP 3: BAM_REMOVE_ORPHANS (Python script)                  │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                             │
│ bampe_rm_orphan.py sample.name.sorted.bam output.bam        │
│                                                             │
│ Rimuove:                                                    │
│  • Singleton reads (read1 senza read2 o viceversa)         │
│  • Optionally: pairs not in FR orientation                 │
│                                                             │
│ Output: sample.bam                                          │
└─────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────┐
│ STEP 4: BAM_SORT_STATS_SAMTOOLS                             │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                             │
│ samtools sort + index + stats                               │
│                                                             │
│ Output: sample.sorted.bam (FINAL)                           │
└─────────────────────────────────────────────────────────────┘
```

---

### pdichiaro/chipseq

```
INPUT: sample.mkD.bam (post-MarkDuplicates)
  │
  ▼
┌─────────────────────────────────────────────────────────────┐
│ PASS 1: Flag-based + Blacklist Filters                      │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                             │
│ # Create include regions (inverse of blacklist)            │
│ bedtools complement -i blacklist.bed -g genome.sizes \      │
│   > include_regions.bed                                     │
│                                                             │
│ samtools view -b -h \                                       │
│   -F 0x0100          # Remove secondary                    │
│   -F 0x0800          # Remove supplementary                │
│   -F 0x0004          # Remove unmapped                     │
│   -F 0x0008          # Remove mate unmapped                │
│   -f 0x0001          # Keep paired                         │
│   -f 0x0002          # Keep proper pairs                   │
│   -F 0x0400          # Remove duplicates (if !keep_dups)   │
│   -L include_regions.bed  # Keep NON-blacklist             │
│   sample.mkD.bam > sample.filter1.bam                       │
│                                                             │
│ Output: sample.filter1.bam                                  │
└─────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────┐
│ PASS 2: MAPQ + Insert Size Filter                           │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                             │
│ samtools view -q 1 -h sample.filter1.bam | \                │
│   awk -v max="500" \                                        │
│     '{if($0~/^@/ || (($9>=0?$9:-$9)<=max)) print}' | \      │
│   samtools view -b > sample.filter2.bam                     │
│                                                             │
│ Output: sample.filter2.bam                                  │
└─────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────┐
│ FINAL: BAM_SORT_SAMTOOLS                                    │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                             │
│ samtools sort + index + stats                               │
│                                                             │
│ Output: sample.filter2.sorted.bam (FINAL)                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔍 FILTRI APPLICATI

### Flags SAM (samtools -F/-f)

| Flag | Hex | nf-core/chipseq | pdichiaro/chipseq | Significato |
|------|-----|-----------------|-------------------|-------------|
| **KEEP (-f)** |
| 0x0001 | 1 | ✅ Yes | ✅ Yes | Paired read |
| 0x0002 | 2 | ❌ No | ✅ Yes | Proper pair |
| **REMOVE (-F)** |
| 0x0004 | 4 | ✅ Yes | ✅ Yes | Unmapped |
| 0x0008 | 8 | ✅ Yes | ✅ Yes | Mate unmapped |
| 0x0100 | 256 | ❌ No | ✅ Yes | Secondary alignment |
| 0x0400 | 1024 | ✅ Yes (optional) | ✅ Yes (optional) | Duplicate |
| 0x0800 | 2048 | ❌ No | ✅ Yes | Supplementary |

**⚠️ DIFFERENZA IMPORTANTE:**
- **nf-core** NON filtra esplicitamente `-f 0x0002` (proper pair)
- **nf-core** NON filtra `-F 0x0100` (secondary) e `-F 0x0800` (supplementary)
- **pdichiaro** è più stringente su questi flag

---

### Insert Size Filter

| Aspetto | nf-core/chipseq | pdichiaro/chipseq |
|---------|----------------|------------------|
| **Tool** | bamtools filter (JSON) | awk script |
| **Range** | -2000 to +2000 bp | 0 to 500 bp |
| **Configurabile** | Sì (JSON file) | Sì (params.insert_size) |
| **Filtering logic** | bamtools built-in | Custom awk: `($9>=0?$9:-$9)<=max` |

**⚠️ GRANDE DIFFERENZA:**
- **nf-core**: Range molto ampio (-2000/+2000) → mantiene anche frammenti molto grandi
- **pdichiaro**: Range stretto (0-500) → più specifico per nucleosome-free regions

---

### MAPQ Filter

| Aspetto | nf-core/chipseq | pdichiaro/chipseq |
|---------|----------------|------------------|
| **Applicato in** | STEP 1 (samtools -q 1) | PASS 2 (samtools -q 1) |
| **Default** | MAPQ >= 1 | MAPQ >= 1 |
| **Opzionale** | Sì (keep_multi_map) | No (sempre applicato) |

---

### Blacklist Filter

| Aspetto | nf-core/chipseq | pdichiaro/chipseq |
|---------|----------------|------------------|
| **Metodo** | `samtools view -L blacklist.bed` | `bedtools complement` + `samtools view -L include_regions.bed` |
| **Logica** | Diretta (esclude blacklist) | Inversa (include solo non-blacklist) |
| **Efficienza** | Alta | Alta |

**⚠️ DIFFERENZA TECNICA:**
- **nf-core**: Usa `-L` direttamente sul file blacklist
- **pdichiaro**: Inverte la blacklist con `bedtools complement` e poi usa `-L`
- Entrambi ottengono lo stesso risultato, ma l'approccio è diverso

---

### Mismatch Filter (NM tag)

| Aspetto | nf-core/chipseq | pdichiaro/chipseq |
|---------|----------------|------------------|
| **Applicato** | ✅ Yes (bamtools) | ❌ No |
| **Threshold** | NM <= 4 | N/A |
| **Scopo** | Remove poor-quality alignments | N/A |

**⚠️ FILTRO UNICO IN nf-core:**
- nf-core filtra reads con troppi mismatches (NM tag > 4)
- pdichiaro NON applica questo filtro

---

### Orphan Removal

| Aspetto | nf-core/chipseq | pdichiaro/chipseq |
|---------|----------------|------------------|
| **Applicato** | ✅ Yes (Python script) | ⚠️ Implicitly (proper pair flag) |
| **Tool** | bampe_rm_orphan.py | samtools -f 0x0002 |
| **Metodo** | Explicit singleton removal | Flag-based filtering |

**⚠️ DIFFERENZA CONCETTUALE:**
- **nf-core**: Step dedicato per rimuovere singleton reads (1 read senza il mate)
- **pdichiaro**: Il flag `-f 0x0002` (proper pair) dovrebbe filtrare gli orphans implicitamente

**🤔 POSSIBILE ISSUE in pdichiaro:**
- Il flag `0x0002` (proper pair) potrebbe non catturare TUTTI i singleton reads
- Se un aligner marca una read come "paired" (0x0001) ma non "proper pair" (0x0002), 
  un singleton potrebbe passare se non c'è un check esplicito
- **nf-core** è più robusto su questo aspetto con il check esplicito via Python

---

## 📊 PARAMETRI CONFIGURABILI

### nf-core/chipseq

```groovy
// In conf/modules.config
withName: 'BAMTOOLS_FILTER' {
    ext.args   = {
        [
            meta.single_end ? '-F 0x004' : '-F 0x004 -F 0x0008 -f 0x001',
            params.keep_dups ? '' : '-F 0x0400',
            params.keep_multi_map ? '' : '-q 1'
        ].join(' ').trim()
    }
}

// In assets/bamtools_filter_pe.json
{
    "filters": [
        { "id": "insert_min", "insertSize": ">=-2000" },
        { "id": "insert_max", "insertSize": "<=2000" },
        { "id": "mismatch", "tag": "NM:<=4" }
    ],
    "rule": " insert_min & insert_max & mismatch "
}
```

### pdichiaro/chipseq

```groovy
// In nextflow.config (o simile)
params {
    insert_size = 500       // Max fragment size
    keep_dups = false       // Keep duplicates?
    mapq = 1                // Min MAPQ
}
```

---

## 🎯 VANTAGGI E SVANTAGGI

### nf-core/chipseq

**✅ VANTAGGI:**
1. **Robusto orphan removal**: Script Python dedicato per rimuovere singleton reads
2. **Mismatch filter**: Filtra reads con troppi mismatches (NM <= 4)
3. **Insert size flessibile**: Range ampio (-2000/+2000) configurabile via JSON
4. **Logging dettagliato**: bampe_rm_orphan.py genera log con statistiche

**❌ SVANTAGGI:**
1. **Complessità**: Richiede 3 tool (samtools, bamtools, Python)
2. **Dipendenze**: Necessita di bamtools e pysam
3. **Performance**: Sorting per nome + orphan removal può essere lento su BAM grandi
4. **Meno stringente su flags**: Non filtra secondary/supplementary alignments

---

### pdichiaro/chipseq

**✅ VANTAGGI:**
1. **Semplicità**: Solo samtools + awk (tool universali)
2. **Performance**: 2 pass veloci senza sorting intermedio
3. **Più stringente**: Filtra secondary (0x0100) e supplementary (0x0800)
4. **Proper pair flag**: Usa `-f 0x0002` per maggiore specificità
5. **Insert size specifico**: Range 0-500bp ottimale per ChIP-seq

**❌ SVANTAGGI:**
1. **Orphan removal implicito**: Dipende dal flag 0x0002, potrebbe non catturare tutti i singleton
2. **No mismatch filter**: Non filtra reads con troppi mismatches
3. **Meno flessibile**: Insert size hardcoded (anche se parametrico)

---

## 🔬 RACCOMANDAZIONI

### Per pdichiaro/chipseq

**OPZIONE 1: Mantenere l'approccio attuale (più semplice)**
- ✅ Già funzionante e performante
- ⚠️ Considera di aggiungere un check esplicito per orphan reads

**OPZIONE 2: Aggiungere orphan removal esplicito (più robusto)**

```bash
# Dopo PASS 2, prima del sort finale
# Name-sort the filtered BAM
samtools sort -n sample.filter2.bam -o sample.filter2.nsort.bam

# Remove orphans (requires Python script o equivalente)
# Opzione A: Usare bampe_rm_orphan.py di nf-core
bampe_rm_orphan.py sample.filter2.nsort.bam sample.filter2.no_orphans.bam

# Opzione B: Usare samtools fixmate + view
samtools fixmate -m sample.filter2.nsort.bam - | \
  samtools view -b -f 0x0001 -F 0x0004 -F 0x0008 > sample.filter2.no_orphans.bam

# Re-sort by coordinate
samtools sort sample.filter2.no_orphans.bam -o sample.filter2.sorted.bam
```

**OPZIONE 3: Aggiungere mismatch filter (opzionale)**

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

## 📝 CONCLUSIONI

**SÌ, nf-core/chipseq usa un approccio multi-step simile:**

| Aspetto | nf-core/chipseq | pdichiaro/chipseq |
|---------|----------------|------------------|
| **Approccio** | 2-step (samtools + bamtools) | 2-pass (samtools only) |
| **Complessità** | Alta (3 tool + Python) | Bassa (samtools + awk) |
| **Robustezza** | Molto alta (orphan removal esplicito) | Alta (orphan removal implicito) |
| **Stringenza flags** | Media | Alta |
| **Insert size range** | Ampio (-2000/+2000) | Stretto (0-500) |
| **Mismatch filter** | ✅ Yes (NM <= 4) | ❌ No |
| **Performance** | Media (name-sort + Python) | Alta (2 pass veloci) |

**📌 RACCOMANDAZIONE FINALE:**

Per **pdichiaro/chipseq**, l'approccio attuale è:
- ✅ **Più semplice** e performante
- ✅ **Più stringente** su SAM flags (secondary/supplementary)
- ⚠️ **Potenzialmente meno robusto** sull'orphan removal (dipende dal flag 0x0002)

**Considera di aggiungere:**
1. ⭐ **Orphan removal esplicito** (come nf-core) per maggiore robustezza
2. 🤔 **Mismatch filter** (opzionale, solo se necessario per il tuo caso d'uso)

Il tuo approccio è **già molto valido** e segue lo stesso principio multi-step di nf-core, 
solo con strumenti diversi (samtools puro vs samtools+bamtools). La scelta dipende dalle tue 
priorità: semplicità/performance vs robustezza massima.
