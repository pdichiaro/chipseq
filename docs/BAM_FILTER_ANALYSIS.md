# Analisi Dettagliata: BAM_FILTER

## 🎯 Confronto tra le Pipeline

### **nf-core/chipseq**

#### Strumenti:
1. **samtools view** (primo passaggio)
2. **bamtools filter** (secondo passaggio - file JSON config)
3. **pysam** (rimozione orphan reads per PE)

#### Sequenza di filtri:

```bash
# Step 1: samtools view (primo filtro)
samtools view \
    -F 0x004 -F 0x0008 -f 0x001  # PE: unmapped, mate unmapped, paired
    -F 0x0400                     # Rimuovi duplicati (se keep_dups=false)
    -q 1                          # RIMUOVI MULTI-MAPPER (se keep_multi_map=false)
    -L blacklist.bed              # Rimuovi blacklist (se presente)
    -b input.bam | \

# Step 2: bamtools filter (file JSON config)
bamtools filter \
    -script bamtools_filter_pe.json  # Applica filtri JSON
```

**File di config bamtools (PE):**
```json
{
    "filters": [
        { "id": "insert_min", "insertSize": ">=-2000" },
        { "id": "insert_max", "insertSize": "<=2000" },
        { "id": "mismatch", "tag": "NM:<=4" }
    ],
    "rule": " insert_min & insert_max & mismatch "
}
```

#### Cosa fa esattamente:
1. ✅ **Secondary alignment removal**: `-F 0x0100` (SEMPRE, anche con keep_multi_map=true)
2. ✅ **Multi-mapper removal**: `samtools view -q 1` → MAPQ >= 1 (se keep_multi_map=false)
3. ✅ **Duplicate removal**: `-F 0x0400` (se keep_dups=false)
4. ✅ **Blacklist removal**: `-L blacklist.bed`
5. ✅ **Insert size filter**: `-2000 <= insert_size <= 2000` (bamtools)
6. ✅ **Mismatch filter**: `NM <= 4` (bamtools)
7. ✅ **Proper pair filter**: `-F 0x004 -F 0x0008 -f 0x001` (samtools)
8. ✅ **Orphan removal**: Script Python pysam (solo PE)

---

### **pdichiaro/chipseq**

#### Strumenti:
1. **samtools view** (entrambi i passaggi)
2. **awk** (filtro insert size)

#### Sequenza di filtri:

```bash
# Step 1: samtools view (primo filtro generale)
samtools view \
    -F 0x004 -F 0x0008 -f 0x001 -f 0x002  # PE: proper pair (più strict!)
    -F 0x0400                              # Rimuovi duplicati (se keep_dups=false)
    -L blacklist.bed                       # Rimuovi blacklist (se presente)
    -b input.bam > filter1.bam

# Step 2: samtools + awk (MAPQ + insert size)
samtools view -q 1 -h filter1.bam | \     # RIMUOVI MULTI-MAPPER (se keep_multi_map=false)
    awk -v var="1000" '{                   # Filtra insert size
        if(substr($0,1,1)=="@" || 
           (($9>=0?$9:-$9)<=var)) 
            print $0
    }' | \
    samtools view -b > filter2.bam
```

#### Cosa fa esattamente:
1. ✅ **Secondary/Supplementary removal**: `-F 0x0100 -F 0x0800` (SEMPRE, anche con keep_multi_map=true)
2. ✅ **Multi-mapper removal**: `samtools view -q 1` → MAPQ >= 1 (se keep_multi_map=false)
3. ✅ **Duplicate removal**: `-F 0x0400` (se keep_dups=false)
4. ✅ **Blacklist removal**: `-L blacklist.bed`
5. ✅ **Insert size filter**: `abs(insert_size) <= 1000` (awk, configurabile)
6. ❌ **NO mismatch filter** (NM non controllato)
7. ✅ **Proper pair filter**: `-F 0x004 -F 0x0008 -f 0x001 -f 0x002` (più strict!)
8. ❌ **NO orphan removal esplicito** (già garantito da proper pair flags)

---

## 📊 Differenze Chiave

| Filtro | nf-core/chipseq | pdichiaro/chipseq | Note |
|--------|----------------|-------------------|------|
| **Secondary align** | `-F 0x0100` | `-F 0x0100 -F 0x0800` | ✅ **IDENTICO** (pdichiaro + supplementary) |
| **Multi-mapper** | `-q 1` (MAPQ≥1) | `-q 1` (MAPQ≥1) | ✅ **IDENTICO** |
| **Duplicati** | `-F 0x0400` | `-F 0x0400` | ✅ **IDENTICO** |
| **Blacklist** | `-L bed` | `-L bed` | ✅ **IDENTICO** |
| **Insert size** | ±2000bp (bamtools) | ≤1000bp (awk) | ⚠️ **DIVERSO** |
| **Mismatch (NM)** | ≤4 (bamtools) | NO | ⚠️ **SOLO nf-core** |
| **Proper pair** | `-f 0x001` | `-f 0x001 -f 0x002` | ⚠️ **pdichiaro PIÙ STRICT** |
| **Orphan removal** | pysam script | Implicit (proper pair) | ⚠️ **Approcci diversi** |

---

## 🎯 **CRITICAL: Primary vs Secondary Alignments**

### **SAM Flags:**
```
0x0100 (256)  = Secondary alignment
0x0800 (2048) = Supplementary alignment
```

### **Bowtie2 Behavior:**

**Without `-k` flag (default):**
- Reports **1 primary alignment** (no flag 0x100)
- MAPQ = 0 if ambiguous (multi-mapper)
- MAPQ > 0 if unique

**With `-k 100` flag:**
- Reports **1 primary alignment** (no flag 0x100, MAPQ=0)
- Reports **up to 99 secondary alignments** (flag 0x100, MAPQ=0)

### **Filter Behavior:**

**Both pipelines ALWAYS remove secondary/supplementary:**
- ✅ **nf-core**: `-F 0x0100` (remove secondary)
- ✅ **pdichiaro**: `-F 0x0100 -F 0x0800` (remove secondary + supplementary)

**Result:**
- 🎯 **Only PRIMARY alignments pass to downstream analysis**
- 🎯 **When keep_multi_map=true**: Keeps primary with MAPQ=0 (random assignment from multi-mapper)
- 🎯 **When keep_multi_map=false**: Removes primary with MAPQ=0 (via `-q 1`)

### **Example Workflow:**

```
READ_001 maps to 3 locations (chr1:100, chr2:200, chr3:300)

Bowtie2 with -k 100:
  ├─ PRIMARY:   chr1:100 (no flag 0x100, MAPQ=0)
  ├─ SECONDARY: chr2:200 (flag 0x100, MAPQ=0)  ← REMOVED by -F 0x100
  └─ SECONDARY: chr3:300 (flag 0x100, MAPQ=0)  ← REMOVED by -F 0x100

After BAM_FILTER:
  keep_multi_map=false: ❌ REMOVED (MAPQ=0, filtered by -q 1)
  keep_multi_map=true:  ✅ KEPT (chr1:100, MAPQ=0, random assignment)
```

**Key Insight:**
- 🔴 **Even with keep_multi_map=true**, you get **ONLY 1 alignment per read**
- 🔴 **Secondary alignments are ALWAYS filtered**, regardless of keep_multi_map
- 🟢 **keep_multi_map controls whether to keep primary alignment with MAPQ=0**

---

## 🔍 Analisi Dettagliata delle Differenze

### 1️⃣ **Insert Size Filter**

**nf-core**: ±2000bp (range simmetrico)
```json
"insertSize": ">=-2000"
"insertSize": "<=2000"
```

**pdichiaro**: ≤1000bp (solo magnitudine)
```bash
awk '(($9>=0?$9:-$9)<=1000)'  # abs(insert_size) <= 1000
```

**Impatto**:
- ✅ **pdichiaro più conservativo**: Rimuove fragment size anomali >1kb
- ⚠️ **nf-core più permissivo**: Accetta fino a 2kb (alcuni H3K9me3 domains)
- 💡 **Configurabile**: `params.inser_size = 1000` (typo da fixare!)

---

### 2️⃣ **Mismatch Filter (NM tag)**

**nf-core**: `"tag": "NM:<=4"` via bamtools
- Rimuove reads con >4 mismatch
- Aumenta qualità mapping (riduce noise)

**pdichiaro**: **ASSENTE**
- Mantiene tutti i reads indipendentemente da NM
- Più permissivo per regioni divergenti

**Impatto**:
- ✅ **nf-core più conservativo**: Quality control più strict
- ⚠️ **pdichiaro più permissivo**: Potenziale noise maggiore
- 💡 **Potenziale aggiunta**: Potremmo aggiungere `-e 'NM<=4'` in awk

---

### 3️⃣ **Proper Pair Flags**

**nf-core**: `-F 0x004 -F 0x0008 -f 0x001`
```
-F 0x004  # read not unmapped
-F 0x0008  # mate not unmapped
-f 0x001  # read paired
```

**pdichiaro**: `-F 0x004 -F 0x0008 -f 0x001 -f 0x002`
```
-F 0x004  # read not unmapped
-F 0x0008  # mate not unmapped
-f 0x001  # read paired
-f 0x002  # read mapped in proper pair  ← EXTRA!
```

**Impatto**:
- ✅ **pdichiaro PIÙ STRICT**: Richiede flag 0x002 (proper pair)
- ✅ **Rimuove automaticamente orphans**: Flag 0x002 garantisce proper pairing
- 💡 **nf-core usa pysam script separato** per rimuovere orphans

---

### 4️⃣ **Orphan Read Removal**

**nf-core**: Script Python separato (`BAM_REMOVE_ORPHANS`)
- Name-sort BAM
- Usa pysam per verificare pairing
- Rimuove reads senza mate

**pdichiaro**: **Implicito via flag 0x002**
- `-f 0x002` garantisce proper pairing
- NO script separato necessario

**Impatto**:
- ✅ **pdichiaro più efficiente**: Un solo passaggio
- ✅ **Risultato equivalente**: Entrambi rimuovono orphans
- 💡 **Approccio diverso ma funzionale**

---

## 🎯 Raccomandazioni

### Opzione A: **Mantenere la tua implementazione**
✅ **Pro**:
- Più semplice (solo samtools + awk)
- Flag 0x002 già rimuove orphans
- Insert size configurabile

⚠️ **Considerare**:
- Aggiungere filtro mismatch? `NM<=4`
- Documentare differenza insert size (1000 vs 2000)

### Opzione B: **Adottare logica nf-core**
✅ **Pro**:
- Filtro mismatch incluso (NM<=4)
- Insert size più permissivo (±2000bp)
- Compatibilità totale

⚠️ **Contro**:
- Richiede bamtools (dipendenza extra)
- Più complesso (3 step invece di 2)

---

## ✅ Conclusione

**Il tuo BAM_FILTER è equivalente a nf-core per i multi-mapper!**

### Gestione Multi-mapper:
- ✅ **IDENTICA**: Entrambi usano `-q 1` (MAPQ >= 1)
- ✅ **keep_multi_map = false**: Rimuove multi-mapper (MAPQ=0)
- ✅ **keep_multi_map = true**: Mantiene multi-mapper (skip `-q 1`)

### Differenze principali:
1. **Insert size**: 1000bp (tuo) vs 2000bp (nf-core) → **Configurabile**
2. **Mismatch**: Assente (tuo) vs NM<=4 (nf-core) → **Potenziale aggiunta**
3. **Proper pair**: Flag 0x002 (tuo) vs pysam script (nf-core) → **Equivalente**

### Raccomandazione finale:
**Mantieni la tua implementazione!** È:
- ✅ Più semplice
- ✅ Più efficiente (meno dipendenze)
- ✅ **IDENTICA per multi-mapper**
- ✅ Proper pair handling più strict (0x002 flag)

**Opzionale**: Aggiungi controllo mismatch in awk:
```bash
awk -v var="1000" '{
    if(substr($0,1,1)=="@") {
        print $0
    } else {
        # Extract NM tag
        for(i=1; i<=NF; i++) {
            if($i ~ /^NM:i:/) {
                split($i, a, ":")
                nm = a[3]
                break
            }
        }
        # Filter by insert size AND mismatch
        if((($9>=0?$9:-$9)<=var) && nm<=4) {
            print $0
        }
    }
}'
```
