# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **Replaced `bin/check_samplesheet.py` with nf-core standard version** (#PR_NUMBER)
  - Adds explicit `replicate` and `control_replicate` columns to input samplesheet format
  - Improves validation logic for replicate/control matching
  - Better error messages for invalid input formats
  - Validated output now includes `replicate` column (7 columns instead of 6)
  - Sample naming convention preserved: `{sample}_REP{n}_T{m}`
  - **Backward compatible**: Workflow logic unchanged, replicate column currently unused
  - See [docs/samplesheet_format.md](docs/samplesheet_format.md) for full format specification

### Added
- Comprehensive samplesheet format documentation (`docs/samplesheet_format.md`)
- Examples for paired-end, single-end, and multiple technical replicates
- Migration guide from old samplesheet format

### Technical Details
- Input format: 7 columns (added `replicate`, `control_replicate`)
- Output format: 7 columns (added `replicate` between `fastq_2` and `antibody`)
- Workflow compatibility: All existing workflow logic uses `meta.id` and `meta.antibody` only
- No breaking changes to downstream processing
- Script backup available at `bin/check_samplesheet.py.backup`

### Migration Notes
For users with existing samplesheets:
1. Remove `_REP{N}` suffixes from sample names
2. Add explicit `replicate` column with integer values (1, 2, 3, ...)
3. Add `control_replicate` column when `control` is specified
4. See migration examples in [docs/samplesheet_format.md](docs/samplesheet_format.md)

## [1.0.0] - 2026-XX-XX

### Added
- Initial release based on nf-core/chipseq template
- Custom BAM filtering workflow integration
- Multiple alignment and peak calling options

---

**Note**: This changelog documents changes from the project's current state. Earlier version history may be incomplete.
