# Analisi del Workflow fgualdr/mmchipseq - Gestione Multi-mapper

## Sommario
Analisi dettagliata di come il workflow **fgualdr/mmchipseq** gestisce i read multi-mapper usando un algoritmo EM-Bayesian.

## Repository
- **URL**: https://github.com/fgualdr/mmchipseq
- **Descrizione**: "This workflow is able to position multi-mappers using an EM-Bayesian algorithm"
- **Derivazione**: nf-core/rnaseq (MIT License)

---

## Architettura del Sistema Multi-mapper

### 1. Parametri Principali

#### A) Configurazione STAR (nextflow.config, righe 41-43)
```groovy
outfiltermultimapnmax   = 500   // Max number of loci a read can map to
outsammultnmax          = 500   // Max alignments to output per read in SAM
winanchormultimapnmax   = 500   // Max multi-mapping for anchor extensions
```

**Significato**: STAR è configurato per **catturare fino a 500 posizioni** per ogni read multi-mapper.

#### B) Parametri Workflow
```groovy
keep_multi_map  = boolean   // Se true: mantiene multi-mapper senza EM
                            // Se false: filtra multi-mapper (solo NH:i:1)

skip_em         = boolean   // Se true: salta algoritmo EM
                            // Se false: esegue EM-Bayesian positioning

em_eps          = 1e-6      // Convergence threshold per algoritmo EM
em_iter         = 1000      // Max iterazioni EM

inser_size      = 1000      // Max fragment size
times_frag      = 4         // Max times fragment size
label_overlap   = 0.25      // Min overlap for read-hotspot intersection
```

---

## 2. Pipeline di Elaborazione

### Fase 1: Allineamento STAR (modules/local/star_align.nf)

```groovy
STAR \
    --outFilterMultimapNmax 500 \          # Cattura fino a 500 posizioni
    --outSAMmultNmax 500 \                 # Output fino a 500 alignments
    --winAnchorMultimapNmax 500 \          # Anchor extensions
    --outMultimapperOrder Random \         # Ordine casuale multi-mapper
    --alignEndsProtrude 0 ConcordantPair \ # Proper pairs
    --alignEndsType EndToEnd \             # End-to-end alignment
    --outSAMattrIHstart 0 \                # Start IH:i tag at 0
    --outFilterScoreMinOverLread 0.3 \     # Min score 30% of read length
    --outFilterMatchNminOverLread 0.3      # Min matches 30% of read length
```

**Output**: BAM con tag NH:i (numero di hit) e HI:i (hit index)

### Fase 2: Merge & Mark Duplicates

```
PICARD_MERGESAMFILES → MARK_DUPLICATES_PICARD
```

### Fase 3: Subworkflow BAM_FILTER_EM

#### 3.1 BAM_FILTER (modules/local/bam_filter.nf)

**Se `keep_multi_map = false`** (default):
```bash
# Step 1: Filtro base
samtools view -F 0x004 -F 0x0008 -f 0x001 -f 0x002  # Proper pairs
             -F 0x0400                               # Remove duplicates (se keep_dups=false)
             -L blacklist.bed                        # Remove blacklisted regions
             -b input.bam > filter1.bam

# Step 2: Filtra per fragment size + rimuove multi-mapper
samtools view -h filter1.bam | \
    awk -v var="1000" '{if(substr($0,1,1)=="@" || (($9>=0?$9:-$9)<=var)) print $0}' | \
    grep -E "(NH:i:1\b|^@)" | \    # MANTIENE SOLO NH:i:1 (unique mappers)
    samtools view -b > filter2.bam
```

**Se `keep_multi_map = true`**:
```bash
# Step 1: Come sopra
# Step 2: Filtra solo per fragment size (MANTIENE multi-mapper)
samtools view -h filter1.bam | \
    awk -v var="1000" '{if(substr($0,1,1)=="@" || (($9>=0?$9:-$9)<=var)) print $0}' | \
    samtools view -b > filter2.bam
```

#### 3.2 BAM_EM_PREP (modules/local/bam_em_prep.nf)

**Se `skip_em = false`** (default):

```bash
# 1. LABELING: Aggiunge HI:i al nome del read
samtools view -h filter2.bam | \
    awk '{for(i=12;i<=NF;i++){if($i~/^HI:i:/){ $1=$1"_"$i}}; print}' | \
    samtools view -bS - > labeled.bam

# 2. Sort by name
samtools sort -n labeled.bam > labeled.nsort.bam

# 3. Converti a BEDPE (paired-end)
bedtools bamtobed -bedpe -i labeled.nsort.bam > labeled.nsort.bedpe

# 4. Estrai SOLO multi-mapper
samtools view -h labeled.nsort.bam | \
    grep -v 'NH:i:1' | \              # ESCLUDE NH:i:1 (unique mappers)
    samtools view -bS - > labeled.multi.bam

bedtools bamtobed -bedpe -i labeled.multi.bam > labeled.nsort.multi.bedpe

# 5. Crea HOTSPOTS (regioni con multi-mapper)
cut -f 1,2,6 labeled.nsort.multi.bedpe > multi.bed
sort -k1,1 -k2,2n multi.bed > multi.sort.bed

# Merge loci vicini (entro insert_size = 1000bp)
bedtools merge -d 1000 -i multi.sort.bed > multi.sort.merged.bed

# Aggiungi ID univoci
awk '{print $0"\t""id_"NR}' multi.sort.merged.bed > multi.hotspots.bed

# 6. Trova intersezioni read-hotspot
bedtools intersect \
    -a labeled.sort.bed \
    -b multi.hotspots.bed \
    -sorted -wo -loj > nsort.match.bed

# 7. Prepara input per EM
# Formato: read_full_id, read_id_ori, target_id
awk '{id=$4; sub("_HI:.*", "", $4); print id, $4, $8}' nsort.match.bed > read_target.txt

# Separa match da no-match
awk '$3!="id_nomatch"{print $1, $2, $3}' read_target.txt > read_target_match.txt
```

**Output**: 
- `read_target_match.txt`: Tabella read → hotspot assignments
- `labeled.nsort.bam`: BAM con read labels
- `multi.hotspots.bed`: Hotspot regions

#### 3.3 BAM_EM (modules/local/bam_em.nf)

**Container**: `docker://fgualdr/empy`

```bash
em_algorithm_bedpe_sm_bis.py \
    -i read_target_match.txt \
    -o ./ \
    -m 1000 \              # Max iterations
    -c 1e-6                # Convergence threshold
```

**Output**:
- `*Final.bedpe`: Read assignments finali dopo EM
- `*posterior_target_probabilities.txt`: Probabilità posteriors

#### 3.4 BAM_EM_OUT (modules/local/bam_em_out.nf)

```bash
# 1. Converti BAM a SAM
samtools view -h labeled.nsort.bam > samp.sam

# 2. Filtra: mantieni solo read in Final.bedpe + unique mappers (NH:i:1)
awk 'FNR==NR{ids[$1];next} 
     {if($1~/^@/){print}
      else{if($1 in ids || $0~/NH:i:1/){print}}}' \
    Final.bedpe samp.sam > filter.sam

# 3. Converti a BAM
samtools view -bS filter.sam > filtered.bam
```

**Output**: `filtered.bam` contenente:
- **Unique mappers** (NH:i:1) - tutti
- **Multi-mapper risolti** - solo quelli assegnati dall'algoritmo EM

### Fase 4: Sort & Index

```
BAM_SORT_SAMTOOLS → output finale
```

---

## 3. Valori di Default STAR

**Documentazione STAR 2.7.0a** (parametri rilevanti per multi-mapper):

```
--outFilterMultimapNmax   default: 10
    Maximum number of loci the read is allowed to map to.
    Alignments will be output only if the read maps to ≤ this value.
    Otherwise, no alignments will be output (counted as "mapped to too many loci").

--outSAMmultNmax          default: -1
    Maximum number of multiple alignments for a read that will be output to SAM/BAM.
    -1 = all alignments (up to --outFilterMultimapNmax) will be output
```

**Implicazioni**:
- **nf-core/chipseq**: NON specifica questi parametri → usa default STAR
  - STAR **cattura** max 10 posizioni per read
  - STAR **output** tutte le 10 posizioni nel BAM
  - Il filtro successivo (`samtools view -q 1`) **rimuove** i multi-mapper
- **fgualdr/mmchipseq**: Specifica valori espliciti molto alti
  - STAR **cattura** max 500 posizioni per read
  - STAR **output** tutte le 500 posizioni nel BAM
  - L'algoritmo EM **risolve** l'ambiguità delle 500 posizioni

---

## 4. Confronto con nf-core/chipseq

| Aspetto | nf-core/chipseq | fgualdr/mmchipseq |
|---------|----------------|-------------------|
| **Aligner** | STAR o Bowtie2 | Solo STAR |
| **Multi-mapper STAR** | Max 10 (default `--outFilterMultimapNmax`) | Max 500 (explicit) |
| **Output multi-mapper** | -1 = All (default `--outSAMmultNmax`) | Max 500 (explicit) |
| **Filtro BAM** | `-q 1` (rimuove NH>1) | Mantiene multi-mapper |
| **Algoritmo EM** | ❌ No | ✅ Sì (opzionale) |
| **Hotspot detection** | ❌ No | ✅ Sì |
| **Fragment filtering** | ❌ No | ✅ Sì (max 1000bp o 4x insert) |
| **Read labeling** | ❌ No | ✅ Sì (HI:i tag in read name) |
| **Final BAM** | Solo unique mappers | Unique + EM-resolved multi-mappers |

---

## 5. Logica dell'Algoritmo EM-Bayesian

### Problema
Un read mappa su **N posizioni** nel genoma. Quale è la posizione corretta?

### Approccio EM

1. **Hotspot Identification**: 
   - Identifica regioni genomiche con alta densità di multi-mapper
   - Merge loci entro `insert_size` (1000bp)

2. **Read-Hotspot Assignment**:
   - Interseca ogni read con gli hotspot
   - Crea tabella: `read_id → [hotspot1, hotspot2, ..., hotspotN]`

3. **EM Algorithm** (iterativo):
   
   **E-step** (Expectation):
   - Calcola probabilità che un read provenga da ciascun hotspot
   - Basato su: coverage attuale di ogni hotspot
   
   **M-step** (Maximization):
   - Ri-stima il coverage di ogni hotspot
   - Basato su: assegnamenti probabilistici dei read
   
   **Convergenza**: Quando variazione coverage < `em_eps` (1e-6)

4. **Final Assignment**:
   - Assegna ogni read all'hotspot con probabilità massima
   - Read assegnati vengono mantenuti nel BAM finale
   - Read non assegnati vengono scartati

### Vantaggi
- ✅ Recupera informazioni biologiche da regioni ripetitive
- ✅ Migliora coverage in loci duplicati/ripetuti
- ✅ Utile per histone marks su elementi ripetitivi (es. centromeri, telomeri)

### Svantaggi
- ❌ Computazionalmente intensivo (500 posizioni × EM iterations)
- ❌ Richiede container custom (`fgualdr/empy`)
- ❌ Può introdurre bias se le assunzioni EM sono violate
- ❌ Solo per STAR (non Bowtie2)

---

## 6. Parametri Raccomandati per Diversi Scenari

### Scenario A: ChIP-seq Standard (TF, broad peaks)
```groovy
keep_multi_map = false
skip_em = true
```
**Risultato**: Solo unique mappers (come nf-core/chipseq)

### Scenario B: ChIP-seq su Regioni Ripetitive (histone marks)
```groovy
keep_multi_map = true
skip_em = false
em_eps = 1e-6
em_iter = 1000
```
**Risultato**: Unique + EM-resolved multi-mappers

### Scenario C: Analisi Esplorativa (massima sensibilità)
```groovy
keep_multi_map = true
skip_em = true
```
**Risultato**: Tutti i read (unique + tutti i multi-mapper)  
**⚠️ ATTENZIONE**: Può causare falsi positivi!

---

## 7. Implementazione nf-core/chipseq

### Opzione 1: Flag per EM Processing (Raccomandato)
```groovy
params.enable_multimapper_em = false  // Default: comportamento attuale

if (params.enable_multimapper_em) {
    // Include BAM_FILTER_EM subworkflow
    // Richiede: fgualdr/empy container, parametri EM
}
```

### Opzione 2: Solo Mantenimento Multi-mapper (Più Semplice)
```groovy
params.keep_multi_map = false  // Default

// In BAM filtering:
if (!params.keep_multi_map) {
    // Attuale: samtools view -q 1
} else {
    // Nuovo: no filtro MAPQ (mantiene multi-mapper)
}
```

### Considerazioni
- **EM algorithm** richiede dipendenze esterne (Python script, container)
- **Hotspot detection** aggiunge complessità computazionale
- **Validazione biologica** necessaria per verificare benefici

---

## 8. File Chiave da Esaminare

1. **Workflow principale**: `workflows/mmchipseq.nf` (righe 320-328)
2. **Subworkflow EM**: `subworkflows/local/bam_filter_em.nf`
3. **Modulo filtro**: `modules/local/bam_filter.nf`
4. **Modulo EM prep**: `modules/local/bam_em_prep.nf`
5. **Modulo EM algo**: `modules/local/bam_em.nf`
6. **Modulo EM output**: `modules/local/bam_em_out.nf`
7. **STAR config**: `modules/local/star_align.nf`

---

## Conclusioni

Il workflow **fgualdr/mmchipseq** implementa un sistema sofisticato per:
1. **Catturare** multi-mapper durante allineamento (STAR con `-outFilterMultimapNmax 500`)
2. **Identificare** hotspot genomici con alta densità di multi-mapper
3. **Risolvere** ambiguità usando algoritmo EM-Bayesian
4. **Mantenere** solo multi-mapper con assegnamento confidenziale

**Trade-off**:
- ➕ Maggiore sensibilità su regioni ripetitive
- ➖ Maggiore complessità computazionale
- ➖ Dipendenze esterne (container custom)
- ➖ Solo STAR (non Bowtie2)

**Adozione in nf-core/chipseq**: Valutare se i benefici giustificano la complessità aggiuntiva, specialmente considerando che la maggior parte degli esperimenti ChIP-seq si concentrano su regioni uniche del genoma.
