# QC Plots Timeline - Quando Partono i Plot di MACS2 e Consensus

## 📊 Ordine di Esecuzione dei Plot QC

### 🔵 LIVELLO 1: QC dei Peak Individuali (MACS2_CALLPEAK_SINGLE)

**Quando partono:**
1. ✅ **MACS2_CALLPEAK_SINGLE** completa il peak calling su ogni campione individuale
2. ✅ I campioni con 0 peaks vengono filtrati e viene emesso un warning
3. ✅ **FRIP_SCORE** calcola il FRiP (Fraction of Reads in Peaks) per ogni campione
4. ✅ **MULTIQC_CUSTOM_PEAKS** prepara i dati per MultiQC

**Poi, SE `!params.skip_peak_annotation`:**
5. ✅ **HOMER_ANNOTATEPEAKS_MACS2** annota i peaks individuali

**Poi, SE `!params.skip_peak_qc`:**

#### 🎨 PLOT_MACS2_QC (Plot QC per peaks individuali)
```groovy
PLOT_MACS2_QC (
    ch_macs2_peaks.collect{it[1]}  // Raccoglie TUTTI i peak files individuali
)
```
**Input**: Tutti i file `.narrowPeak` o `.broadPeak` dai campioni individuali

**Output** (directory: `results/macs2/qc/`):
- `macs2_peak.counts_plot.pdf` - Grafico del numero di peaks per campione
- `macs2_peak.widths_plot.pdf` - Distribuzione delle larghezze dei peaks
- Altri plot statistici sui peaks individuali

#### 🎨 PLOT_HOMER_ANNOTATEPEAKS (Plot annotazioni individuali)
```groovy
PLOT_HOMER_ANNOTATEPEAKS (
    HOMER_ANNOTATEPEAKS_MACS2.out.txt.collect{it[1]},
    ch_peak_annotation_header,
    "_peaks.annotatePeaks.txt"
)
```
**Input**: Tutti i file di annotazione Homer dai campioni individuali

**Output** (directory: `results/macs2/qc/`):
- `peaks.annotatePeaks.summary.pdf` - Distribuzione genomica dei peaks (promoter, intron, exon, etc.)
- `peaks.annotatePeaks.summary.tsv` - Dati per MultiQC

---

### 🟢 LIVELLO 2: QC dei Consensus Peaks BY CONDITION

**Quando partono:**
1. ✅ **MACS2_CONSENSUS_BY_CONDITION** completa il consensus per ogni condizione
   - Es: `WT_BCATENIN` (da WT_BCATENIN_REP1 + WT_BCATENIN_REP2)
   - Es: `NAIVE_BCATENIN` (da NAIVE_BCATENIN_REP1 + NAIVE_BCATENIN_REP2)

**Poi, SE `!params.skip_peak_annotation`:**
2. ✅ **HOMER_ANNOTATEPEAKS_CONSENSUS_CONDITION** annota i consensus peaks by condition

**Poi, SE `!params.skip_peak_qc`:**

#### 🎨 PLOT_MACS2_QC_CONSENSUS_CONDITION (Plot QC per consensus by condition)
```groovy
PLOT_MACS2_QC_CONSENSUS_CONDITION (
    MACS2_CONSENSUS_BY_CONDITION.out.peaks.collect{it[1]}
)
```
**Input**: Tutti i file consensus `.narrowPeak` o `.broadPeak` per ogni condizione

**Output** (directory: `results/macs2/consensus_peaks/{antibody}/by_condition/qc/`):
- `macs2_peak.condition.counts_plot.pdf` - Numero di peaks per condizione
- `macs2_peak.condition.widths_plot.pdf` - Distribuzione larghezze per condizione
- Statistiche dei consensus peaks filtrati (min_reps_consensus = 2)

#### 🎨 PLOT_HOMER_ANNOTATEPEAKS_CONSENSUS_CONDITION (Plot annotazioni consensus by condition)
```groovy
PLOT_HOMER_ANNOTATEPEAKS_CONSENSUS_CONDITION (
    HOMER_ANNOTATEPEAKS_CONSENSUS_CONDITION.out.txt.collect{it[1]},
    ch_peak_annotation_header,
    "_peaks.condition.annotatePeaks.txt"
)
```
**Input**: Annotazioni Homer per ogni condizione

**Output** (directory: `results/macs2/consensus_peaks/{antibody}/by_condition/qc/`):
- `peaks.condition.annotatePeaks.summary.pdf` - Distribuzione genomica per condizione
- `peaks.condition.annotatePeaks.summary.tsv` - Dati per MultiQC

---

### 🟣 LIVELLO 3: Consensus Finale BY ANTIBODY (MACS2_CONSENSUS)

**Quando parte:**
1. ✅ **MACS2_CONSENSUS** completa il merge finale per antibody
   - Es: `BCATENIN` (da WT_BCATENIN + NAIVE_BCATENIN)

**Poi, SE `!params.skip_peak_annotation`:**
2. ✅ **HOMER_ANNOTATEPEAKS_CONSENSUS** annota il consensus finale
3. ✅ **ANNOTATE_BOOLEAN_PEAKS** aggiunge le colonne boolean

**⚠️ NOTA IMPORTANTE**: 
Non ci sono plot QC specifici per il livello finale by antibody nel workflow attuale.
I plot sono generati solo per:
- Peaks individuali (livello 1)
- Consensus by condition (livello 2)

---

## 🕐 Timeline Completa

```
Start
  │
  ├─► MACS2_CALLPEAK_SINGLE (su ogni campione)
  │     ↓
  │   FRIP_SCORE
  │     ↓
  │   HOMER_ANNOTATEPEAKS_MACS2
  │     ↓
  │   🎨 PLOT_MACS2_QC (LIVELLO 1)
  │     ↓
  │   🎨 PLOT_HOMER_ANNOTATEPEAKS (LIVELLO 1)
  │
  ├─► MACS2_CONSENSUS_BY_CONDITION (per ogni condizione)
  │     ↓
  │   HOMER_ANNOTATEPEAKS_CONSENSUS_CONDITION
  │     ↓
  │   🎨 PLOT_MACS2_QC_CONSENSUS_CONDITION (LIVELLO 2)
  │     ↓
  │   🎨 PLOT_HOMER_ANNOTATEPEAKS_CONSENSUS_CONDITION (LIVELLO 2)
  │
  └─► MACS2_CONSENSUS (per ogni antibody - finale)
        ↓
      HOMER_ANNOTATEPEAKS_CONSENSUS
        ↓
      ANNOTATE_BOOLEAN_PEAKS
        ↓
      (NO QC PLOTS - output finale pronto)
```

---

## ⚙️ Parametri per Controllare i Plot

### Disabilitare completamente i plot QC:
```bash
--skip_peak_qc
```
Questo salta **TUTTI** i plot di QC (livello 1 e 2)

### Disabilitare le annotazioni (e quindi i plot):
```bash
--skip_peak_annotation
```
Questo salta le annotazioni Homer e i relativi plot

---

## 📂 Directory di Output

```
results/
└── macs2/
    ├── qc/                                    # QC LIVELLO 1 (peaks individuali)
    │   ├── macs2_peak.counts_plot.pdf
    │   ├── macs2_peak.widths_plot.pdf
    │   └── peaks.annotatePeaks.summary.pdf
    │
    └── consensus_peaks/
        └── {ANTIBODY}/                        # Es: BCATENIN/
            ├── by_condition/                  # QC LIVELLO 2 (consensus by condition)
            │   ├── qc/
            │   │   ├── macs2_peak.condition.counts_plot.pdf
            │   │   ├── macs2_peak.condition.widths_plot.pdf
            │   │   └── peaks.condition.annotatePeaks.summary.pdf
            │   ├── WT_BCATENIN_peaks.narrowPeak
            │   └── NAIVE_BCATENIN_peaks.narrowPeak
            │
            └── {ANTIBODY}.bed                 # LIVELLO 3 (finale - no QC plots)
                {ANTIBODY}.boolean.txt
                {ANTIBODY}.saf
```

---

## 🎯 Cosa Aspettarsi Durante l'Esecuzione

1. **Primi plot a partire**: PLOT_MACS2_QC e PLOT_HOMER_ANNOTATEPEAKS
   - Partono subito dopo MACS2_CALLPEAK_SINGLE
   - Utilizzano i peak files individuali

2. **Plot intermedi**: PLOT_MACS2_QC_CONSENSUS_CONDITION e PLOT_HOMER_ANNOTATEPEAKS_CONSENSUS_CONDITION
   - Partono dopo il consensus by condition
   - Mostrano statistiche sui peaks filtrati (min_reps = 2)

3. **Output finale**: Nessun plot QC automatico
   - Il file `{ANTIBODY}.boolean.txt` contiene tutte le info per analisi custom
   - Puoi creare plot custom usando R/Python sui file finali

---

## 💡 Suggerimento per Plot Custom del Livello 3

Se vuoi generare plot per il consensus finale by antibody, puoi usare il boolean.txt:

```R
# Esempio R per plot custom
library(ggplot2)

# Carica il file boolean
peaks <- read.table("BCATENIN.boolean.txt", header=TRUE, sep="\t")

# Plot: numero di peaks per condizione
conditions <- colnames(peaks)[5:ncol(peaks)]
peak_counts <- colSums(peaks[,5:ncol(peaks)])

ggplot(data.frame(Condition=conditions, Peaks=peak_counts), 
       aes(x=Condition, y=Peaks)) +
  geom_bar(stat="identity") +
  theme_minimal() +
  labs(title="BCATENIN Peaks by Condition")
```
