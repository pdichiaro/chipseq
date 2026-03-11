# Confronto Gestione Multi-mapper: pdichiaro/chipseq vs nf-core/chipseq vs fgualdr/mmchipseq

## 📋 Sommario Esecutivo

Analisi comparativa di come tre pipeline ChIP-seq gestiscono i read multi-mapper (read che mappano in più posizioni del genoma).

---

## 🔬 Configurazioni STAR

### pdichiaro/chipseq (Tua Pipeline)
**File**: `nextflow.config` (righe 48-49)

```groovy
params.outfiltermultimapnmax = 1    // Max loci per read
params.outsammultnmax = 1           // Max alignments in output
```

**Comportamento STAR**:
- ✅ **Cattura**: Max 1 posizione per read → **Solo unique mappers**
- ✅ **Output**: Max 1 alignment nel BAM
- ✅ **Risultato**: Multi-mapper vengono **scartati** da STAR stesso

**Applicazione**: `modules/local/star_align.nf`
```bash
STAR \
    --outFilterMultimapNmax $params.outfiltermultimapnmax \  # = 1
    --outSAMmultNmax $params.outsammultnmax \                # = 1
    ...
```

---

### nf-core/chipseq (Originale)
**File**: Nessuna configurazione esplicita

```groovy
# NON specifica outfiltermultimapnmax
# NON specifica outsammultnmax
```

**Comportamento STAR** (valori di default):
- ✅ **Cattura**: Max 10 posizioni per read (`--outFilterMultimapNmax` default = 10)
- ✅ **Output**: Tutte le posizioni nel BAM (`--outSAMmultNmax` default = -1 = all)
- ⚠️ **Risultato**: Multi-mapper sono **presenti** nel BAM (con NH:i > 1)

**Tag nel BAM**:
- `NH:i:1` → Unique mapper (MAPQ tipicamente alto)
- `NH:i:10` → Multi-mapper con 10 posizioni (MAPQ = 0)

---

### fgualdr/mmchipseq (EM-Bayesian)
**File**: `nextflow.config` (righe 41-43)

```groovy
params.outfiltermultimapnmax = 500   // Max loci per read
params.outsammultnmax = 500          // Max alignments in output
params.winanchormultimapnmax = 500   // Anchor extensions
```

**Comportamento STAR**:
- ✅ **Cattura**: Max 500 posizioni per read
- ✅ **Output**: Tutte le 500 posizioni nel BAM
- ✅ **Risultato**: Multi-mapper con **massima risoluzione**

---

## 🔧 Configurazioni Bowtie2

### pdichiaro/chipseq (Tua Pipeline) - **ALIGNED WITH nf-core**
**File**: `conf/modules.config` (BOWTIE2_ALIGN section)

```groovy
ext.args = { meta ->
    def base_args = '--very-sensitive --end-to-end --reorder'  // NO -k flag (nf-core compatible)
    def pe_args = meta.single_end ? '' : ' -X 1000'
    return base_args + pe_args
}
```

**Comportamento Bowtie2** (identico a nf-core/chipseq):
```bash
bowtie2 --very-sensitive --end-to-end --reorder -X 1000
```
- ✅ **Report**: 1 alignment (default Bowtie2)
- ⚠️ **Multi-mapper**: Riporta **1 alignment casuale** con MAPQ = 0
- ✅ **Tag**: AS:i (alignment score), XS:i (suboptimal score)
- ✅ **Fragment size**: `-X 1000` → Max insert size 1000bp per PE reads

**Differenza da nf-core**: 
- pdichiaro usa `-X 1000` (max insert size)
- nf-core non specifica `-X` (usa default Bowtie2 = 500bp)

---

### nf-core/chipseq (Originale)
**File**: `conf/modules.config` (BOWTIE2_ALIGN section)

```groovy
ext.args = {
    [
        meta.read_group ? "--rg-id ${meta.id} --rg SM:${meta.id} ..." : '',
        params.seq_center ? "--rg CN:${params.seq_center}" : ''
    ].join(' ').trim()
}
```

**Comportamento Bowtie2**:
- ✅ **Report**: 1 alignment (default Bowtie2, NO `-k` flag)
- ⚠️ **Multi-mapper**: 1 alignment casuale con MAPQ = 0
- ✅ **Read Groups**: Aggiunti per tracking

**Differenza chiave**: NON permette di mantenere multi-mapper (no `-k` option)

---

### fgualdr/mmchipseq (EM-Bayesian)
**File**: Non usa Bowtie2 (solo STAR)

---

## 🧬 Filtro BAM Post-Allineamento

### pdichiaro/chipseq - `modules/local/bam_filter.nf`

#### Scenario A: `keep_multi_map = false` (DEFAULT)
```bash
# Step 1: Filtri base
samtools view \
    -F 0x004 -F 0x0008 -f 0x001 -f 0x002 \  # Proper pairs (PE)
    -F 0x0400 \                              # Remove duplicates (se keep_dups=false)
    -L blacklist.bed \                       # Remove blacklist
    -b input.bam > filter1.bam

# Step 2: Rimuovi multi-mapper + filtro fragment size
samtools view -q 1 -h filter1.bam | \       # MAPQ >= 1 (rimuove MAPQ=0 multi-mapper)
    awk -v var="1000" '{
        if(substr($0,1,1)=="@" || (($9>=0?$9:-$9)<=var)) 
            print $0
    }' | \
    samtools view -b > filter2.bam
```

**Filtro MAPQ**:
- `-q 1` → **Rimuove** tutti i read con MAPQ < 1
- **STAR**: Multi-mapper con NH:i > 1 hanno MAPQ = 0 → **rimossi**
- **Bowtie2**: Multi-mapper (ambigui) hanno MAPQ = 0 → **rimossi**

**Fragment size**: Max 1000bp (default `params.inser_size`)

---

#### Scenario B: `keep_multi_map = true`
```bash
# Step 1: Filtri base (come sopra)

# Step 2: SOLO filtro fragment size (NO filtro MAPQ)
samtools view -h filter1.bam | \            # Nessun -q flag
    awk -v var="1000" '{
        if(substr($0,1,1)=="@" || (($9>=0?$9:-$9)<=var)) 
            print $0
    }' | \
    samtools view -b > filter2.bam
```

**Risultato**: Multi-mapper **mantenuti** nel BAM finale

---

### nf-core/chipseq - `modules/local/bamtools_filter.nf`

```bash
# Step 1: Filtri base con samtools
samtools view \
    -F 0x004 -F 0x0008 -f 0x001 \          # Proper pairs (PE)
    -F 0x0400 \                             # Remove duplicates (se keep_dups=false)
    -q 1 \                                  # MAPQ >= 1 (rimuove multi-mapper se keep_multi_map=false)
    -L blacklist.bed \                      # Remove blacklist
    -b input.bam | \

# Step 2: Filtri avanzati con bamtools
bamtools filter \
    -out output.bam \
    -script bamtools_filter_pe.json
```

**bamtools_filter_pe.json**:
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

**Filtro MAPQ**:
- Configurable: `-q 1` se `keep_multi_map = false` (default)
- **Fragment size**: -2000 to +2000 bp (più permissivo di pdichiaro)
- **Mismatch**: Max 4 mismatch per read (tag NM)

---

### fgualdr/mmchipseq - `modules/local/bam_filter.nf` + EM Algorithm

#### Step 1: Filtro Base (se `keep_multi_map = false`)
```bash
samtools view -h filter1.bam | \
    grep -E "(NH:i:1\b|^@)" | \            # MANTIENE SOLO NH:i:1 (unique mappers)
    samtools view -b > filter2.bam
```

#### Step 2: EM Preparation (se `skip_em = false`)
```bash
# 1. Label reads con HI:i tag
awk '{for(i=12;i<=NF;i++){if($i~/^HI:i:/){ $1=$1"_"$i}}; print}'

# 2. Estrai SOLO multi-mapper
grep -v 'NH:i:1' | samtools view -bS - > multi.bam

# 3. Identifica HOTSPOTS (regioni con alta densità multi-mapper)
bedtools merge -d 1000 -i multi.sort.bed > hotspots.bed

# 4. Interseca read con hotspot
bedtools intersect -a reads.bed -b hotspots.bed > read_hotspot_map.txt
```

#### Step 3: EM Algorithm (`modules/local/bam_em.nf`)
```python
em_algorithm_bedpe_sm_bis.py \
    -i read_target_match.txt \
    -m 1000 \              # Max iterations
    -c 1e-6                # Convergence threshold
```

**Output**: Assegnamento probabilistico read → hotspot

#### Step 4: Final BAM
```bash
# Mantieni: unique mappers (NH:i:1) + EM-resolved multi-mappers
awk 'FNR==NR{ids[$1];next} 
     {if($1~/^@/){print}
      else{if($1 in ids || $0~/NH:i:1/){print}}}' \
    EM_Final.bedpe input.sam > output.sam
```

---

## 📊 Tabella Comparativa Completa

| Caratteristica | pdichiaro/chipseq | nf-core/chipseq | fgualdr/mmchipseq |
|---------------|-------------------|-----------------|-------------------|
| **STAR: Max loci catturati** | 1 | 10 (default) | 500 |
| **STAR: Output nel BAM** | 1 | 10 (all, default -1) | 500 |
| **STAR: Multi-mapper** | ❌ Scartati da STAR | ✅ Presenti (NH>1, MAPQ=0) | ✅ Presenti (max 500) |
| **Bowtie2: Default** | 1 alignment | 1 alignment | ❌ Non supportato |
| **Bowtie2: `-k` flag** | ❌ No (nf-core aligned) | ❌ No | ❌ N/A |
| **Bowtie2: Multi-mapper** | 1 casuale (MAPQ=0) | 1 casuale (MAPQ=0) | ❌ N/A |
| **Filtro MAPQ** | `-q 1` (opzionale) | `-q 1` (opzionale) | grep NH:i:1 (custom) |
| **Fragment size PE** | ≤1000bp | ±2000bp | ≤1000bp |
| **Mismatch filter** | ❌ No | ✅ NM≤4 | ❌ No |
| **Algoritmo EM** | ❌ No | ❌ No | ✅ Sì (opzionale) |
| **Hotspot detection** | ❌ No | ❌ No | ✅ Sì |
| **Final output** | Unique only | Unique only | Unique + EM-resolved |
| **Complessità** | 🟢 Bassa | 🟡 Media | 🔴 Alta |
| **Tempo compute** | 🟢 Veloce | 🟡 Moderato | 🔴 Lento |

---

## 🎯 Raccomandazioni per Scenario

### 1. Standard ChIP-seq (TF, H3K4me3, H3K27ac)
**Usa**: `pdichiaro/chipseq` o `nf-core/chipseq` con **default** (`keep_multi_map = false`)

**Motivo**:
- ✅ Regioni target sono tipicamente uniche
- ✅ Multi-mapper introducono rumore/falsi positivi
- ✅ Veloce e computazionalmente efficiente

**Configurazione**:
```groovy
params.keep_multi_map = false  // Default
params.aligner = 'bowtie2'     // Più veloce di STAR per genomi piccoli
```

---

### 2. ChIP-seq su Regioni Ripetitive (H3K9me3, centromeri, telomeri)
**Usa**: `fgualdr/mmchipseq` con **EM algorithm**

**Motivo**:
- ✅ Target in regioni ripetitive (multi-mapper biologicamente rilevanti)
- ✅ EM risolve ambiguità basandosi su coverage locale
- ⚠️ Richiede più risorse computazionali

**Configurazione**:
```groovy
params.keep_multi_map = true
params.skip_em = false
params.outfiltermultimapnmax = 500
params.aligner = 'star'        // Richiesto per EM
```

---

### 3. ChIP-seq Esplorativo (massima sensibilità)
**Usa**: `pdichiaro/chipseq` con `keep_multi_map = true`

**Motivo**:
- ✅ Mantiene multi-mapper per analisi downstream
- ✅ Più semplice di EM (no hotspot detection)
- ⚠️ Attenzione a falsi positivi

**Configurazione**:
```groovy
params.keep_multi_map = true
params.aligner = 'bowtie2'     // Usa -k 100
# Oppure
params.aligner = 'star'        // Usa default (10 loci)
```

---

## 🔍 Dettagli Tecnici: MAPQ e Multi-mapper

### STAR Alignment
```
Read A mappa in 1 posizione  → NH:i:1, MAPQ = 255 (unique)
Read B mappa in 2 posizioni  → NH:i:2, MAPQ = 0 (ambiguo)
Read C mappa in 10 posizioni → NH:i:10, MAPQ = 0 (multi-mapper)
```

**Filtro `-q 1`**:
- ✅ Keep: Read A (MAPQ 255 ≥ 1)
- ❌ Remove: Read B, C (MAPQ 0 < 1)

### Bowtie2 Alignment
```
Read A: 1 alignment             → MAPQ = 42 (AS:i:100, no XS:i)
Read B: 2 alignments (report 1)→ MAPQ = 0 (AS:i:90, XS:i:85)
Read C: 100 alignments (-k 100)→ MAPQ = 0 (primary + 99 secondary)
```

**Filtro `-q 1`**:
- ✅ Keep: Read A (MAPQ 42 ≥ 1)
- ❌ Remove: Read B, C (MAPQ 0 < 1)

**Flag 0x100** (secondary alignment):
- Read C con `-k 100`: 1 primary + 99 secondary (flag 0x100)
- Filtro `-F 0x100` rimuove i 99 secondary, mantiene solo 1 primary

---

## 🧪 Esempio Pratico: Read Multi-mapper

### Scenario: Read mappa su gene duplicato (GENE_A e GENE_B)

#### pdichiaro/chipseq (STAR con outfiltermultimapnmax=1)
```
STAR → ❌ Read scartato (mappa in >1 locus)
Output: 0 alignments
```

#### nf-core/chipseq (STAR default)
```
STAR → ✅ Output 2 alignments con NH:i:2, MAPQ=0
Filtro MAPQ → ❌ Rimossi (MAPQ < 1)
Output: 0 alignments
```

#### pdichiaro/chipseq (Bowtie2 default)
```
Bowtie2 → ✅ Output 1 alignment casuale (GENE_A o GENE_B), MAPQ=0
Filtro MAPQ → ❌ Rimosso (MAPQ < 1)
Output: 0 alignments
```

#### pdichiaro/chipseq (Bowtie2 -k 100 + keep_multi_map=true)
```
Bowtie2 → ✅ Output 2 alignments (GENE_A primary, GENE_B secondary), MAPQ=0
Filtro MAPQ → ✅ Mantenuti (no -q flag)
Output: 2 alignments
```

#### fgualdr/mmchipseq (EM algorithm)
```
STAR → ✅ Output 2 alignments con NH:i:2, MAPQ=0
EM → Coverage analysis:
  - GENE_A region: 50 reads (25 unique + 25 multi)
  - GENE_B region: 10 reads (5 unique + 5 multi)
EM → Probability: 83% GENE_A, 17% GENE_B
Output: 1 alignment assigned to GENE_A
```

---

## 💡 Conclusioni

### Differenze Chiave tra Pipeline

1. **pdichiaro/chipseq**:
   - ✅ **Flessibilità**: Opzione `keep_multi_map` per entrambi gli aligner
   - ✅ **STAR strict**: Default outfiltermultimapnmax=1 (solo unique)
   - ✅ **Bowtie2 flexible**: Opzionale -k 100 per multi-mapper
   - 🎯 **Best per**: ChIP-seq standard + opzione esplorativa

2. **nf-core/chipseq**:
   - ✅ **Standard consolidato**: STAR default (10 loci) + filtro MAPQ
   - ✅ **bamtools**: Filtri avanzati (mismatch, insert size)
   - ✅ **Fragment size**: Più permissivo (±2000bp)
   - 🎯 **Best per**: ChIP-seq production-ready, broad compatibility

3. **fgualdr/mmchipseq**:
   - ✅ **EM-Bayesian**: Risoluzione probabilistica multi-mapper
   - ✅ **Hotspot detection**: Identifica regioni ripetitive
   - ✅ **Massima cattura**: STAR 500 loci
   - ⚠️ **Complessità**: Richiede container custom + Python scripts
   - 🎯 **Best per**: ChIP-seq su elementi ripetitivi (H3K9me3, centromeri)

---

## 📚 Riferimenti Tecnici

### STAR Default Values (v2.7.0a)
- `--outFilterMultimapNmax 10`: Max loci per read
- `--outSAMmultNmax -1`: Output all alignments (up to outFilterMultimapNmax)
- `--outSAMprimaryFlag OneBestScore`: Primary flag al migliore alignment

### Bowtie2 Default Values
- **No `-k` flag**: Report 1 alignment (best o random se tie)
- `-k 100`: Report fino a 100 alignments
- `--reorder`: Output in ordine di input FASTQ
- `--very-sensitive`: Preset (-D 20 -R 3 -N 0 -L 20 -i S,1,0.50)

### BAM Flags Rilevanti
- `0x004` (4): Unmapped
- `0x008` (8): Mate unmapped
- `0x001` (1): Paired
- `0x002` (2): Proper pair
- `0x0400` (1024): Duplicate
- `0x100` (256): Secondary alignment

### SAM Tags
- `NH:i`: Number of reported alignments (STAR)
- `HI:i`: Hit index (0-based, STAR)
- `AS:i`: Alignment score (STAR, Bowtie2)
- `XS:i`: Suboptimal alignment score (Bowtie2)
- `NM:i`: Edit distance
