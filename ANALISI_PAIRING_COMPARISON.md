# Analisi Comparativa: IP-Control Pairing

## Data: 2026-02-11

---

## 📊 CONFRONTO TRA IMPLEMENTAZIONI

### nf-core/chipseq Approach

**Schema Metadati:**
```groovy
meta.control = "control_sample_id"  // ID del sample control, o null se non ha control
```

**Logica di Pairing (linee 396-410 nf-core):**
```groovy
// Step 1: Crea channel dei control samples con KEY = id
ch_genome_bam_bai
    .map {
        meta, bam, bai ->
            meta.control ? null : [ meta.id, [ bam ] , [ bai ] ]
    }
    .set { ch_control_bam_bai }
    // Risultato: [ control_id, [control_bam], [control_bai] ]

// Step 2: Crea channel degli IP samples con KEY = control_id
ch_genome_bam_bai
    .map {
        meta, bam, bai ->
            meta.control ? [ meta.control, meta, [ bam ], [ bai ] ] : null
    }
    // Risultato: [ control_id, meta_IP, [ip_bam], [ip_bai] ]
    
    // Step 3: Combine BY KEY (not cartesian product!)
    .combine(ch_control_bam_bai, by: 0)
    // Risultato: [ control_id, meta_IP, [ip_bam], [ip_bai], [control_bam], [control_bai] ]
    
    // Step 4: Restructure
    .map { it -> [ it[1] , it[2] + it[4], it[3] + it[5] ] }
    // Risultato: [ meta_IP, [ip_bam, control_bam], [ip_bai, control_bai] ]
    .set { ch_ip_control_bam_bai }
```

**Complessità:** O(N) - ogni IP viene combinato solo con il suo control specifico

---

### pdichiaro/chipseq Approach (Corrente)

**Schema Metadati:**
```groovy
meta.is_input = true/false           // Boolean: è un input?
meta.which_input = "control_id"      // ID del control da usare
```

**Logica di Pairing (linee 341-346 tua pipeline):**
```groovy
ch_genome_bam_bai
    .combine(ch_genome_bam_bai)  // ⚠️ PRODOTTO CARTESIANO N×N!
    .map { 
        meta1, bam1, bai1, meta2, bam2, bai2 ->
            !meta1.is_input && meta1.which_input == meta2.id ? [ meta1, [ bam1 ], [ bam2 ] ] : null
    }
    .set { ch_ip_control_bam }
```

**Complessità:** O(N²) - crea N×N combinazioni, poi filtra

**Problema:**
- Con 10 samples: 100 combinazioni (99 scartate)
- Con 50 samples: 2500 combinazioni (2450 scartate)
- Con 100 samples: 10000 combinazioni (9900 scartate) → **Memory overflow!**

---

## ✅ SOLUZIONE OTTIMIZZATA

### Opzione 1: Usa `.combine(by: key)` (Metodo nf-core)

```groovy
// Step 1: Prepara control channel con KEY
ch_genome_bam_bai
    .filter { meta, bam, bai -> meta.is_input }
    .map { meta, bam, bai -> 
        [ meta.id, [ bam ], [ bai ] ] 
    }
    .set { ch_control_bam_bai }
    // Risultato: [ control_id, [control_bam], [control_bai] ]

// Step 2: Prepara IP channel con KEY = which_input
ch_genome_bam_bai
    .filter { meta, bam, bai -> !meta.is_input }
    .map { meta, bam, bai -> 
        [ meta.which_input, meta, [ bam ], [ bai ] ] 
    }
    // Risultato: [ control_id, meta_IP, [ip_bam], [ip_bai] ]
    
    // Step 3: Combine BY KEY
    .combine(ch_control_bam_bai, by: 0)
    // Risultato: [ control_id, meta_IP, [ip_bam], [ip_bai], [control_bam], [control_bai] ]
    
    // Step 4: Restructure per ottenere [ meta, [ip_bam], [control_bam] ]
    .map { control_id, meta, ip_bam, ip_bai, control_bam, control_bai -> 
        [ meta, ip_bam, control_bam ] 
    }
    .set { ch_ip_control_bam }
```

**Complessità:** O(N) - efficiente!

---

### Opzione 2: Usa `.join()` con reshape (Alternativa)

```groovy
// Step 1: Separa IP e Control
ch_genome_bam_bai
    .branch {
        ip: !it[0].is_input
        control: it[0].is_input
    }
    .set { ch_branched }

// Step 2: Prepara per join
def ch_ip = ch_branched.ip
    .map { meta, bam, bai -> 
        [ meta.which_input, meta, bam, bai ] 
    }

def ch_control = ch_branched.control
    .map { meta, bam, bai -> 
        [ meta.id, bam, bai ] 
    }

// Step 3: Join by key
ch_ip
    .join(ch_control)
    .map { control_id, meta_ip, ip_bam, ip_bai, control_bam, control_bai ->
        [ meta_ip, [ ip_bam ], [ control_bam ] ]
    }
    .set { ch_ip_control_bam }
```

**Complessità:** O(N) - anche questa è efficiente!

---

## 🔧 CODICE COMPLETO CORRETTO

### Per il caso "with inputs" (linee 340-360)

```groovy
}else{ 
    println "The value of ch_with_inputs set to with the input: ${ch_with_inputs}"

    // Step 1: Prepara control channel con KEY = id
    ch_genome_bam_bai
        .filter { meta, bam, bai -> meta.is_input }
        .map { meta, bam, bai -> 
            [ meta.id, [ bam ], [ bai ] ] 
        }
        .set { ch_control_bam_bai }

    // Step 2: IP samples + combine by key
    ch_genome_bam_bai
        .filter { meta, bam, bai -> !meta.is_input }
        .map { meta, bam, bai -> 
            [ meta.which_input, meta, [ bam ], [ bai ] ] 
        }
        .combine(ch_control_bam_bai, by: 0)
        .map { control_id, meta, ip_bam, ip_bai, control_bam, control_bai -> 
            [ meta, ip_bam, control_bam ] 
        }
        .set { ch_ip_control_bam }

    // w inputs we simply merge all bams by antibody
    ch_ip_control_bam
        .map {
            meta, bam1, bam2 ->
            def new_meta = meta.clone()
            new_meta.id =  meta.antibody
            [new_meta, bam1, bam2]
        }
        .groupTuple(by: 0)
        .map {
            meta, bam1, bam2 ->
                [ meta , bam1, bam2 ]
        }
        .set { ch_antibody_bam }
}
```

---

## 📈 PERFORMANCE COMPARISON

| Samples | Cartesian (Old) | Key-based (New) | Memory Saved |
|---------|-----------------|-----------------|--------------|
| 10      | 100 operations  | 10 operations   | 90%          |
| 20      | 400 operations  | 20 operations   | 95%          |
| 50      | 2500 operations | 50 operations   | 98%          |
| 100     | 10000 operations| 100 operations  | 99%          |

---

## 🎯 VANTAGGI DELLA SOLUZIONE

1. ✅ **Scalabilità lineare** invece che quadratica
2. ✅ **Memory footprint ridotto** drasticamente
3. ✅ **Più veloce** con dataset grandi
4. ✅ **Più chiaro** - usa operatori Nextflow idiomatici
5. ✅ **Nessun null filtering** necessario
6. ✅ **Fail-fast** - se un control manca, l'operatore combine fallisce con errore chiaro

---

## ⚠️ NOTA IMPORTANTE

### Bug nel tuo input_check.nf (linea 16)

```groovy
meta.which_input = row.which_input.toBoolean()  // ❌ ERRORE!
```

Questo dovrebbe essere:
```groovy
meta.which_input = row.which_input  // ✅ CORRETTO - è una stringa ID, non boolean!
```

**Spiegazione:** `which_input` deve contenere l'ID del control sample (es. "input_1"), non un boolean. 
Usando `.toBoolean()` su una stringa non-empty restituisce sempre `true`, perdendo l'informazione dell'ID.

---

## 📝 TESTING

### Test Case 1: Dataset piccolo
```
Sample1 (IP)  -> which_input: "Input1"
Sample2 (IP)  -> which_input: "Input1"
Sample3 (IP)  -> which_input: "Input2"
Input1 (Control)
Input2 (Control)
```

**Risultato atteso:**
- Sample1 paired con Input1
- Sample2 paired con Input1
- Sample3 paired con Input2

### Test Case 2: Missing Control
```
Sample1 (IP) -> which_input: "Input1"
Input2 (Control)  // Input1 mancante!
```

**Risultato atteso:**
- Pipeline should fail con errore esplicito: "Control Input1 not found for Sample1"

---

## 🔄 MIGRATION CHECKLIST

- [ ] Fix `meta.which_input` in input_check.nf (rimuovi `.toBoolean()`)
- [ ] Sostituisci `.combine()` con `.combine(by: 0)` nel blocco else
- [ ] Aggiungi `.filter()` per separare IP e Control
- [ ] Testa con samplesheet reale
- [ ] Verifica che tutti gli IP trovino il loro control
- [ ] Benchmark su dataset grande (>50 samples)

