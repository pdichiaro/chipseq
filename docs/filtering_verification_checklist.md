# ✅ Checklist Verifica Filtri Post-Alignment

## 1. 📊 Statistiche Generali

### A. Retention Rate
- [ ] **Retention rate 60-80%**: OK, tipico per ChIP-seq di buona qualità
- [ ] **Retention rate 40-60%**: Borderline, verificare qualità dati input
- [ ] **Retention rate <40%**: ⚠️ PROBLEMA - controllare:
  - Tasso di duplicati molto alto
  - Presenza massiccia di blacklist regions
  - Troppi multi-mappers
  - Fragment size distribution anomala

**Come verificare:**
```bash
TOTAL_INPUT=$(samtools view -c input.bam)
TOTAL_FILTERED=$(samtools view -c filtered.bam)
RETENTION=$(awk "BEGIN {printf \"%.2f\", ($TOTAL_FILTERED / $TOTAL_INPUT) * 100}")
echo "Retention rate: ${RETENTION}%"
```

---

## 2. 🎯 Verifiche Specifiche Flags

### A. Secondary Alignments
- [ ] **FILTERED BAM = 0 secondary alignments**
  
```bash
samtools view -c -f 0x100 filtered.bam
# Expected: 0
```

**Se NON zero:**
- ❌ ERRORE: I filtri non sono stati applicati correttamente
- Verificare che `-F 0x100` sia presente nei filtri

---

### B. Supplementary Alignments
- [ ] **FILTERED BAM = 0 supplementary alignments**

```bash
samtools view -c -f 0x800 filtered.bam
# Expected: 0
```

**Se NON zero:**
- ❌ ERRORE: Chimeric reads non filtrati correttamente

---

### C. Unmapped Reads
- [ ] **FILTERED BAM = 0 unmapped reads**

```bash
samtools view -c -f 0x004 filtered.bam
# Expected: 0
```

---

### D. Proper Pairs (PE only)
- [ ] **FILTERED BAM = 100% properly paired**

```bash
TOTAL=$(samtools view -c -F 0x004 filtered.bam)
PROPER=$(samtools view -c -f 0x002 filtered.bam)
PCT=$(awk "BEGIN {printf \"%.2f\", ($PROPER / $TOTAL) * 100}")
echo "Properly paired: ${PCT}%"
# Expected: 100%
```

**Se <100%:**
- ⚠️ Verificare che `-f 0x002` sia nei filtri
- Possibile presenza di singletons

---

### E. Duplicates
- [ ] **FILTERED BAM = 0 duplicates** (se `keep_dups=false`)

```bash
samtools view -c -f 0x400 filtered.bam
# Expected: 0 (default)
```

**Tasso tipico di duplicati (INPUT BAM):**
- 10-30%: ✅ Ottimo
- 30-50%: ⚠️ Borderline
- >50%: ❌ Problema - bassa complessità libreria

---

### F. Multi-mappers (MAPQ=0)
- [ ] **FILTERED BAM = 0 reads con MAPQ=0** (se `keep_multi_map=false`)

```bash
samtools view filtered.bam | awk '$5==0' | wc -l
# Expected: 0 (default mode)
```

**Tasso tipico multi-mappers (INPUT BAM):**
- <5%: ✅ Eccellente
- 5-15%: ✅ Buono
- 15-30%: ⚠️ Borderline
- >30%: ❌ Genoma ripetitivo o scarsa qualità mappatura

---

## 3. 📏 Insert Size Distribution (PE only)

### A. Range Normale
- [ ] **Picco principale: 100-300 bp** (nucleosome-sized fragments)
- [ ] **Tail <500 bp**: Maggior parte dei fragments
- [ ] **Fragments >500 bp rimossi**

**Come verificare:**
```bash
# Distribuzione input
samtools view -f 0x002 input.bam | \
    awk '{if($9>0) print $9}' | \
    sort -n | \
    uniq -c > input_insert_sizes.txt

# Distribuzione filtered
samtools view -f 0x002 filtered.bam | \
    awk '{if($9>0) print $9}' | \
    sort -n | \
    uniq -c > filtered_insert_sizes.txt

# Verifica max insert size in filtered
MAX_INSERT=$(samtools view -f 0x002 filtered.bam | \
    awk '{if($9>0) print $9}' | \
    sort -n | tail -1)
echo "Max insert size in filtered BAM: $MAX_INSERT"
# Expected: ≤ params.insert_size (default 500)
```

**Se MAX_INSERT > params.insert_size:**
- ❌ ERRORE: Filtro insert size non applicato correttamente
- Verificare il comando awk nel processo BAM_FILTER

---

## 4. 🚫 Blacklist Filtering

### A. Reads in Blacklist Regions
- [ ] **FILTERED BAM: 0 reads in blacklist** (ideale)
- [ ] **FILTERED BAM: <0.1% reads in blacklist** (accettabile)

**Come verificare:**
```bash
TOTAL=$(samtools view -c filtered.bam)
IN_BL=$(bedtools intersect -a filtered.bam -b blacklist.bed -u | samtools view -c -)
PCT=$(awk "BEGIN {printf \"%.4f\", ($IN_BL / $TOTAL) * 100}")
echo "Reads in blacklist: $IN_BL ($PCT%)"
# Expected: 0 or <0.1%
```

**Se >0.1%:**
- ⚠️ Possibile overlap parziale (read che overlappa ma non è completamente dentro blacklist)
- Verificare che `-L blacklist.bed` sia nei filtri samtools
- Considerare filtro più stringente con bedtools

---

### B. Top Blacklist Regions
- [ ] **Verificare che centromeri/telomeri siano rappresentati**

```bash
bedtools coverage -a blacklist.bed -b input.bam | \
    sort -k4 -rn | \
    head -20
# Expected: Vedere centromeri (es. chr1:121-156M), telomeri, regioni ripetitive
```

---

## 5. 📍 Coverage per Cromosoma

### A. Distribuzione Normale
- [ ] **Coverage proporzionale alla lunghezza cromosoma**
- [ ] **No picchi anomali su chrM** (mitocondrio)

**Come verificare:**
```bash
samtools idxstats filtered.bam | \
    awk '{if($1!="*") print $1"\t"$3"\t"$2}' | \
    sort -k2 -rn
```

**Red flags:**
- chrM con >10% total reads → Contaminazione mitocondriale
- chrY assente in sample femminile → OK
- chrY presente in sample femminile → ⚠️ Contaminazione

---

## 6. 🎨 MAPQ Distribution

### A. Post-Filtering (keep_multi_map=false)
- [ ] **MAPQ minimo ≥ 1**
- [ ] **Maggioranza reads: MAPQ ≥ 20**

```bash
samtools view filtered.bam | \
    awk '{print $5}' | \
    sort -n | \
    uniq -c | \
    sort -rn
```

**Distribuzione ideale:**
```
Count    MAPQ
500000   42    ← High quality unique mappers
300000   40
200000   30
100000   20
 50000   10
     0    0    ← Multi-mappers rimossi
```

---

## 7. 📈 File di Output da Verificare

### A. File Obbligatori
- [ ] `SAMPLE.mLb.clN.sorted.bam` - BAM filtrato finale
- [ ] `SAMPLE.mLb.clN.sorted.bam.bai` - Index
- [ ] `samtools_stats/SAMPLE.flagstat` - Statistiche
- [ ] `samtools_stats/SAMPLE.stats` - Statistiche dettagliate
- [ ] `samtools_stats/SAMPLE.idxstats` - Stats per cromosoma

### B. Verifica Dimensioni File
```bash
ls -lh *.bam
# FILTERED BAM dovrebbe essere 60-80% dimensione INPUT BAM
```

---

## 8. 🚨 Segnali di Allarme

### ❌ PROBLEMI CRITICI
1. **Retention rate <40%**
   - Causa: Eccesso duplicati, blacklist, multi-mappers, insert size
   - Azione: Investigare distribuzione filtri individuali

2. **Presenza secondary/supplementary in FILTERED**
   - Causa: Filtri non applicati
   - Azione: Verificare flags `-F 0x100 -F 0x800`

3. **MAPQ=0 presente in FILTERED** (keep_multi_map=false)
   - Causa: Filtro `-q 1` non applicato
   - Azione: Controllare processo BAM_FILTER

4. **Insert size >params.insert_size in FILTERED**
   - Causa: Filtro awk non funzionante
   - Azione: Debuggare awk command

---

## 9. ✅ Parametri Ottimali

### A. Parametri Consigliati
```groovy
params {
    keep_multi_map = false     // Rimuovi multi-mappers
    keep_dups = false          // Rimuovi duplicati
    insert_size = 500          // Fragment size filter (PE)
    blacklist = "path/to/blacklist.bed"  // ENCODE blacklist
}
```

### B. Parametri Permissivi (per debugging)
```groovy
params {
    keep_multi_map = true      // Mantieni multi-mappers
    keep_dups = true           // Mantieni duplicati
    insert_size = 1000         // Fragment size più permissivo
    blacklist = false          // No blacklist filtering
}
```

---

## 10. 📊 Report Finale

### Template di Report
```
=== FILTERING REPORT ===
Sample: SAMPLE_NAME
Date: YYYY-MM-DD

INPUT STATISTICS:
  Total reads:        10,000,000
  Duplicates:          2,000,000 (20%)
  Multi-mappers:       1,000,000 (10%)
  In blacklist:          500,000 (5%)
  Insert >500bp:         300,000 (3%)

FILTERED STATISTICS:
  Total reads:         7,000,000
  Retention rate:      70%
  MAPQ ≥ 1:            100%
  Proper pairs:        100%
  In blacklist:        0 (0%)

VERDICT: ✅ PASS
  - Retention rate within expected range (60-80%)
  - All quality filters applied correctly
  - No reads in blacklist regions
  - Insert size distribution normal
```

---

## Comandi Rapidi per Verifica Completa

```bash
# Script all-in-one
./verify_filtering.sh SAMPLE_NAME results/

# Verifica specifica blacklist
./verify_blacklist.sh SAMPLE_NAME results/ blacklist.bed

# Genera plots
python plot_filtering_stats.py \
    results/samtools_stats/SAMPLE.input.flagstat \
    results/samtools_stats/SAMPLE.filtered.flagstat \
    results/qc/plots/
```

---

**Autore**: Seqera AI  
**Versione**: 1.0  
**Data**: 2026-04-14
