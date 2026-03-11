# Fragment Size Filtering: ChIP-seq vs ATAC-seq Analysis

## Executive Summary

Il filtro sul **fragment size** nel file `bam_filter.nf` del pipeline ChIP-seq è **ALTAMENTE RILEVANTE ma RICHIEDE ADATTAMENTO** per ATAC-seq a causa delle differenze biologiche fondamentali tra le due tecniche.

---

## 🧬 Differenze Biologiche Fondamentali

### ChIP-seq Fragment Size Distribution
- **Range tipico**: 200-600 bp (dipende dal protocollo di sonicazione/tagmentazione)
- **Ottimale**: 200-500 bp per la maggior parte degli esperimenti
- **Upper bound comune**: 500-1000 bp
- **Distribuzione**: Relativamente uniforme, senza pattern nucleosomali marcati
- **Obiettivo**: Catturare regioni legate da TF/istoni senza troppo DNA flanking

### ATAC-seq Fragment Size Distribution
- **Pattern periodico nucleosomale** con picchi distinti:
  - **<100 bp** (38-100 bp): **Nucleosome-Free Regions (NFR)** ⭐
  - **~200 bp** (150-200 bp): Mono-nucleosomale
  - **~400 bp** (300-400 bp): Di-nucleosomale
  - **~600 bp**: Tri-nucleosomale
- **Distribuzione**: Pattern oscillatorio decrescente
- **NFR dominante**: Un dataset ATAC-seq di alta qualità mostra un picco NFR **predominante**

---

## 📊 Fragment Size Filtering Strategy

### ChIP-seq (Approccio Attuale)
```groovy
// modules/local/bam_filter.nf
def max_frag = params.insert_size ? params.insert_size.toInteger() : 1000

// Filter: Keep fragments <= 1000 bp
awk -v var="$max_frag" '{if(substr(\$0,1,1)=="@" || ((\$9>=0?\$9:-\$9)<=var)) print \$0}'
```
**Logica**: 
- Rimuove frammenti troppo lunghi (>1000 bp) che sono noise o artefatti
- Upper bound conservativo per mantenere la maggior parte del segnale biologico

### ATAC-seq Considerations

#### ❌ **NON applicare lo stesso filtro rigidamente**
Il filtro ChIP-seq con upper bound a 1000 bp è **troppo permissivo** per ATAC-seq se l'obiettivo è analizzare principalmente le NFR.

#### ✅ **Strategie Raccomandate per ATAC-seq**

1. **Conservare TUTTO il pattern nucleosomale** (approccio standard nf-core/atacseq)
   ```bash
   # NO hard filtering sul fragment size
   # Mantieni: 38 bp - 2000 bp (cattura NFR + tutti i pattern nucleosomali)
   # Reason: Preserva informazioni biologiche complete
   ```
   - **Pro**: Analisi completa dell'architettura cromatinica
   - **Uso**: QC metrics (TSS enrichment, nucleosome signal), peak calling comprensivo

2. **Separare NFR per analisi specifica** (post-alignment)
   ```bash
   # Filtraggio stratificato basato su categoria biologica:
   # NFR: 38-100 bp → TF footprinting, motif discovery
   # Mono-nuc: 150-200 bp → Nucleosome positioning
   # Di-nuc+: >200 bp → Architettura 3D, loop detection
   ```
   - **Pro**: Massima flessibilità analitica
   - **Uso**: Downstream analysis (TF footprinting, differential accessibility)

3. **Filtro upper bound conservativo** (compromesso)
   ```bash
   # Upper bound: 1000-2000 bp
   # Reason: Rimuove frammenti artefattuali molto lunghi ma preserva tri-nucleosomali
   ```
   - **Pro**: Rimuove artefatti tecnici mantenendo segnale biologico
   - **Uso**: General-purpose ATAC-seq analysis

---

## 🎯 Raccomandazioni Specifiche

### Per un Pipeline ATAC-seq

#### Fase 1: Alignment & Initial Filtering
```groovy
// NO hard filtering on fragment size during BAM filtering
// Solo rimozione di:
// - Low MAPQ (<30)
// - Mitochondrial reads (chrM)
// - Duplicates (opzionale)
// - Blacklisted regions

// Upper bound conservativo se necessario:
def max_frag = 2000  // Cattura fino a tri-nucleosomali + buffer
```

#### Fase 2: Fragment Size Stratification (downstream)
```groovy
// Post-filtering per analisi specifiche:

// NFR analysis (TF binding, motif discovery)
samtools view -h input.bam | \
  awk '{if(substr($0,1,1)=="@" || (($9>=38 && $9<=100) || ($9<=-38 && $9>=-100))) print $0}' | \
  samtools view -b > nfr.bam

// Mono-nucleosomal (nucleosome positioning)
samtools view -h input.bam | \
  awk '{if(substr($0,1,1)=="@" || (($9>=150 && $9<=200) || ($9<=-150 && $9>=-200))) print $0}' | \
  samtools view -b > mono_nuc.bam

// All sub-1kb (general accessible chromatin)
samtools view -h input.bam | \
  awk -v var="1000" '{if(substr($0,1,1)=="@" || (($9>=0?$9:-$9)<=var)) print $0}' | \
  samtools view -b > accessible.bam
```

#### Fase 3: QC Metrics Generation
```bash
# Fragment length distribution plot (CRITICAL for ATAC-seq QC)
# Deve mostrare pattern periodico nucleosomale

# TSS enrichment score (NFR vs background)
# Threshold: >=1.5 per dataset di alta qualità

# Nucleosome signal (mono-nuc / NFR ratio)
# Threshold: <=2 per dataset di alta qualità

# FRiP (Fraction of Reads in Peaks)
# Threshold: >=0.3 per ATAC-seq
```

---

## 📌 Key Takeaways

1. **Il filtro ChIP-seq (max 1000 bp) è utilizzabile per ATAC-seq** ma come **upper bound conservativo**, non come filtro primario

2. **ATAC-seq richiede stratificazione** dei frammenti per categoria biologica (NFR, mono-nuc, etc.) piuttosto che hard filtering

3. **Preservare il pattern nucleosomale completo** è essenziale per QC metrics affidabili

4. **NFR filtering** (38-100 bp) dovrebbe essere fatto **downstream** per analisi specifiche (TF footprinting, motif discovery)

5. **Fragment length distribution plot** è il QC più importante in ATAC-seq - deve essere generato PRIMA di qualsiasi filtering decisionale

---

## 🔧 Implementazione Pratica

### Se stai adattando questo ChIP-seq pipeline per ATAC-seq:

```groovy
// Opzione A: Parametro condizionale
params.assay_type = 'chipseq'  // o 'atacseq'

process BAM_FILTER {
    script:
    def max_frag = params.assay_type == 'atacseq' ? 2000 : (params.insert_size ?: 1000)
    
    // Resto del filtering...
}

// Opzione B: Modulo separato per ATAC-seq
// modules/local/bam_filter_atacseq.nf
// - NO fragment size filtering nel BAM principale
// - Genera BAM stratificati per downstream analysis
// - Calcola QC metrics specifici ATAC-seq
```

### Tool Raccomandati per ATAC-seq
- **ATACseqQC** (R/Bioconductor): Fragment size distribution, TSS enrichment
- **deepTools**: bigWig generation, heatmaps
- **MACS2/MACS3**: Peak calling (parameter: `--nomodel --shift -75 --extsize 150` for NFR)
- **ENCODE pipeline**: Reference implementation per ATAC-seq standard

---

## 📚 References
- ENCODE ATAC-seq pipeline: https://www.encodeproject.org/atac-seq/
- nf-core/atacseq: https://nf-co.re/atacseq
- Buenrostro et al. (2013): "Transposition of native chromatin for fast and sensitive epigenomic profiling"
- Corces et al. (2017): "An improved ATAC-seq protocol reduces background and enables interrogation of frozen tissues"

---

**Conclusione**: Il filtro è utile anche per ATAC-seq, ma con parametri adattati (upper bound più alto) e idealmente con stratificazione post-filtering per preservare le informazioni biologiche specifiche del pattern nucleosomale.
