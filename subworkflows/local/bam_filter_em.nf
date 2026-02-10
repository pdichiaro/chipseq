//
// Filter BAM file using standard ChIP-seq approach (removes multimappers)
// EM algorithm for multimapper resolution is available but disabled by default (skip_em = true)
//

include { BAM_FILTER     } from '../../modules/local/bam_filter'
include { BAM_EM_PREP } from '../../modules/local/bam_em_prep'
include { BAM_EM } from '../../modules/local/bam_em'
include { BAM_EM_OUT } from '../../modules/local/bam_em_out'
include { BAM_SORT_SAMTOOLS  } from '../nf-core/bam_sort_samtools'
 
workflow BAM_FILTER_EM {
    take:
    ch_bam_bai   // channel: [ val(meta), [ bam ] ]
    ch_bed                    // channel: [ bed ]
    ch_fasta                     // channel: [ fasta ]
    ch_chrom_sizes            // chanel: [chr_sizes]
    bamtools_filter_se_config //    file: BAMtools filter JSON config file for SE data
    bamtools_filter_pe_config //    file: BAMtools filter JSON config file for  PE data

    main:

    ch_versions = Channel.empty()

    //
    // STANDARD ChIP-seq FILTERING (default: skip_em = true)
    // Removes multimappers (NH:i:1 filter), duplicates, blacklist regions,
    // unmapped reads, and filters by fragment size
    //
    // OPTIONAL: EM algorithm for multimapper resolution (skip_em = false)
    // The EM algorithm can redistribute multimapping reads to probable locations,
    // but this is NOT standard ChIP-seq practice and is disabled by default
    //
    
    BAM_FILTER( ch_bam_bai, ch_bed )
    ch_versions = ch_versions.mix(BAM_FILTER.out.versions.first())

    if( !params.skip_em ) {
        // Optional: EM algorithm for multimapper resolution
        // This is NOT recommended for standard ChIP-seq analysis
        
        BAM_EM_PREP(BAM_FILTER.out.bam, ch_chrom_sizes) 
        ch_versions = ch_versions.mix(BAM_EM_PREP.out.versions.first())

        BAM_EM(BAM_EM_PREP.out.read_target_match)
        ch_versions = ch_versions.mix(BAM_EM.out.versions.first())
        
        BAM_EM_PREP
            .out
            .bam_label
            .join(BAM_EM.out.final_bedpe, by: [0])
            .set { ch_em_bam }
        
        BAM_EM_OUT( ch_em_bam, ch_chrom_sizes ) 
        ch_versions = ch_versions.mix(BAM_EM_OUT.out.versions.first())
        ch_filter_bam = BAM_EM_OUT.out.bam

    } else {
        // Standard ChIP-seq: use filtered BAM without EM processing
        ch_filter_bam = BAM_FILTER.out.bam
    }
    
    // Process for downstream
    BAM_SORT_SAMTOOLS(ch_filter_bam)
    ch_versions = ch_versions.mix(BAM_SORT_SAMTOOLS.out.versions.first())

    emit:

    bam      = BAM_SORT_SAMTOOLS.out.bam      // channel: [ val(meta), [ bam ] ]
    bai      = BAM_SORT_SAMTOOLS.out.bai      // channel: [ val(meta), [ bai ] ]
    stats    = BAM_SORT_SAMTOOLS.out.stats    // channel: [ val(meta), [ stats ] ]
    flagstat = BAM_SORT_SAMTOOLS.out.flagstat // channel: [ val(meta), [ flagstat ] ]
    idxstats = BAM_SORT_SAMTOOLS.out.idxstats // channel: [ val(meta), [ idxstats ] ]

    versions = ch_versions                    // channel: [ versions.yml ]
}

