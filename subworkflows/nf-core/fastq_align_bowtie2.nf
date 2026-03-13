//
// Alignment with Bowtie2
//

include { BOWTIE2_ALIGN      } from '../../modules/nf-core/modules/bowtie2/align/main'
include { BAM_SORT_SAMTOOLS  } from './bam_sort_samtools'

workflow FASTQ_ALIGN_BOWTIE2 {
    take:
    ch_reads          // channel: [ val(meta), [ reads ] ]
    ch_index          // channel: [ val(meta), path(index) ]
    save_unaligned    // val: boolean
    sort_bam          // val: boolean
    ch_fasta          // channel: [ val(meta), path(fasta) ]

    main:

    def ch_versions = channel.empty()

    //
    // Debug: Check channel contents before BOWTIE2_ALIGN
    //
    ch_reads
        .view { meta, reads -> "DEBUG ch_reads: meta=${meta}, reads=${reads}" }
        .set { ch_reads_debug }
    
    ch_index
        .view { meta, path -> "DEBUG ch_index: meta=${meta}, path=${path}" }
        .set { ch_index_debug }
    
    ch_fasta
        .view { meta, path -> "DEBUG ch_fasta: meta=${meta}, path=${path}" }
        .set { ch_fasta_debug }

    //
    // Map reads with Bowtie2
    //
    BOWTIE2_ALIGN ( ch_reads_debug, ch_index_debug, ch_fasta_debug, save_unaligned, sort_bam )
    ch_versions = ch_versions.mix(BOWTIE2_ALIGN.out.versions.first())

    //
    // Sort, index BAM file and run samtools stats, flagstat and idxstats
    //
    BAM_SORT_SAMTOOLS ( BOWTIE2_ALIGN.out.bam )
    ch_versions = ch_versions.mix(BAM_SORT_SAMTOOLS.out.versions)

    emit:
    bam_orig         = BOWTIE2_ALIGN.out.bam            // channel: [ val(meta), bam ]
    log_out          = BOWTIE2_ALIGN.out.log            // channel: [ val(meta), log ]
    fastq            = BOWTIE2_ALIGN.out.fastq          // channel: [ val(meta), fastq ]

    bam              = BAM_SORT_SAMTOOLS.out.bam        // channel: [ val(meta), [ bam ] ]
    bai              = BAM_SORT_SAMTOOLS.out.bai        // channel: [ val(meta), [ bai ] ]
    csi              = BAM_SORT_SAMTOOLS.out.csi        // channel: [ val(meta), [ csi ] ]
    stats            = BAM_SORT_SAMTOOLS.out.stats      // channel: [ val(meta), [ stats ] ]
    flagstat         = BAM_SORT_SAMTOOLS.out.flagstat   // channel: [ val(meta), [ flagstat ] ]
    idxstats         = BAM_SORT_SAMTOOLS.out.idxstats   // channel: [ val(meta), [ idxstats ] ]

    versions         = ch_versions                      // channel: [ versions.yml ]
}
