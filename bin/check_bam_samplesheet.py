#!/usr/bin/env python3

import os
import sys
import errno
import argparse
import re


def parse_args(args=None):
    Description = "Reformat pdichiaro/chipseq BAM samplesheet file and check its contents."
    Epilog = "Example usage: python check_bam_samplesheet.py <FILE_IN> <FILE_OUT>"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument("FILE_IN", help="Input BAM samplesheet file.")
    parser.add_argument("FILE_OUT", help="Output file.")
    return parser.parse_args(args)


def make_dir(path):
    if len(path) > 0:
        try:
            os.makedirs(path)
        except OSError as exception:
            if exception.errno != errno.EEXIST:
                raise exception


def print_error(error, context="Line", context_str=""):
    error_str = "ERROR: Please check samplesheet -> {}".format(error)
    if context != "" and context_str != "":
        error_str = "ERROR: Please check samplesheet -> {}\n{}: '{}'".format(
            error, context.strip(), context_str.strip()
        )
    print(error_str)
    sys.exit(1)


def check_bam_samplesheet(file_in, file_out):
    """
    This function checks that the BAM samplesheet follows the following structure:
    sample,bam,bai,replicate,antibody,control,control_replicate
    SPT5_T0,SPT5_T0_rep1.bam,SPT5_T0_rep1.bam.bai,1,SPT5,SPT5_INPUT,1
    SPT5_T0,SPT5_T0_rep2.bam,SPT5_T0_rep2.bam.bai,2,SPT5,SPT5_INPUT,2
    SPT5_INPUT,SPT5_INPUT_rep1.bam,SPT5_INPUT_rep1.bam.bai,1,,,
    SPT5_INPUT,SPT5_INPUT_rep2.bam,SPT5_INPUT_rep2.bam.bai,2,,,
    """

    sample_mapping_dict = {}
    with open(file_in, "r", encoding="utf-8-sig") as fin:
        ## Check header
        MIN_COLS = 3
        HEADER = ["sample", "bam", "bai", "replicate", "antibody", "control", "control_replicate"]
        header = [x.strip('"') for x in fin.readline().strip().split(",")]
        if header[: len(HEADER)] != HEADER:
            print(f"ERROR: Please check samplesheet header -> {','.join(header)} != {','.join(HEADER)}")
            sys.exit(1)

        ## Check sample entries
        for line_number, line in enumerate(fin, start=1):
            if line.strip():
                lspl = [x.strip().strip('"') for x in line.strip().split(",")]

                # Check valid number of columns per row
                if len(lspl) < len(HEADER):
                    print_error(
                        "Invalid number of columns (found = {}, minimum = {})!".format(len(lspl), len(HEADER)),
                        "Line {}".format(line_number),
                        line,
                    )
                num_cols = len([x for x in lspl[: len(HEADER)] if x])
                if num_cols < MIN_COLS:
                    print_error(
                        "Invalid number of populated columns (found = {}, minimum = {})!".format(num_cols, MIN_COLS),
                        "Line {}".format(line_number),
                        line,
                    )

                ## Check sample name entries
                sample, bam, bai, replicate, antibody, control, control_replicate = lspl[: len(HEADER)]
                if sample.find(" ") != -1:
                    print(f"WARNING: Spaces have been replaced by underscores for sample: {sample}")
                    sample = sample.replace(" ", "_")
                if not sample:
                    print_error("Sample entry has not been specified!", "Line {}".format(line_number), line)
                if not re.match(r"^[a-zA-Z0-9_.-]+$", sample):
                    print_error(
                        "Sample name contains invalid characters! Only alphanumeric characters, underscores, dots and dashes are allowed.",
                        "Line {}".format(line_number),
                        line,
                    )

                ## Check BAM file extension
                if bam:
                    if bam.find(" ") != -1:
                        print_error("BAM file contains spaces!", "Line {}".format(line_number), line)
                    if not bam.endswith(".bam"):
                        print_error(
                            "BAM file does not have extension '.bam'!",
                            "Line {}".format(line_number),
                            line,
                        )
                else:
                    print_error("BAM file must be specified!", "Line {}".format(line_number), line)

                ## Check BAI file extension (optional)
                if bai:
                    if bai.find(" ") != -1:
                        print_error("BAI file contains spaces!", "Line {}".format(line_number), line)
                    if not (bai.endswith(".bai") or bai.endswith(".bam.bai")):
                        print_error(
                            "BAI file does not have extension '.bai' or '.bam.bai'!",
                            "Line {}".format(line_number),
                            line,
                        )

                ## Check replicate column is integer
                if not replicate.isdecimal():
                    print_error("Replicate id not an integer!", "Line {}".format(line_number), line)
                    sys.exit(1)

                ## Check antibody and control columns have valid values
                if antibody:
                    if antibody.find(" ") != -1:
                        print(f"WARNING: Spaces have been replaced by underscores for antibody: {antibody}")
                        antibody = antibody.replace(" ", "_")
                    if not control:
                        print_error(
                            "Both antibody and control columns must be specified!",
                            "Line {}".format(line_number),
                            line,
                        )

                if control:
                    if control.find(" ") != -1:
                        print(f"WARNING: Spaces have been replaced by underscores for control: {control}")
                        control = control.replace(" ", "_")
                    if not control_replicate.isdecimal():
                        print_error("Control replicate id not an integer!", "Line {}".format(line_number), line)
                        sys.exit(1)
                    control = "{}_REP{}".format(control, control_replicate)
                    if not antibody:
                        print_error(
                            "Both antibody and control columns must be specified!",
                            "Line {}".format(line_number),
                            line,
                        )

                ## Create sample info: [bam, bai, replicate, antibody, control]
                sample_info = [bam, bai, replicate, antibody, control]

                ## Create sample mapping dictionary
                replicate = int(replicate)
                sample_info = sample_info + lspl[len(HEADER) :]
                if sample not in sample_mapping_dict:
                    sample_mapping_dict[sample] = {}
                if replicate not in sample_mapping_dict[sample]:
                    sample_mapping_dict[sample][replicate] = [sample_info]
                else:
                    if sample_info in sample_mapping_dict[sample][replicate]:
                        print_error("Samplesheet contains duplicate rows!", "Line {}".format(line_number), line)
                    else:
                        sample_mapping_dict[sample][replicate].append(sample_info)

    ## Write validated samplesheet with appropriate columns
    if len(sample_mapping_dict) > 0:
        out_dir = os.path.dirname(file_out)
        make_dir(out_dir)
        with open(file_out, "w") as fout:
            fout.write(",".join(["sample", "bam", "bai", "replicate", "antibody", "control"]) + "\n")
            for sample in sorted(sample_mapping_dict.keys()):
                ## Check that replicate ids are in format 1..<num_replicates>
                uniq_rep_ids = sorted(list(set(sample_mapping_dict[sample].keys())))
                if len(uniq_rep_ids) != max(uniq_rep_ids) or 1 != min(uniq_rep_ids):
                    print_error(
                        "Replicate ids must start with 1..<num_replicates>!",
                        "Sample",
                        "{}, replicate ids: {}".format(sample, ",".join([str(x) for x in uniq_rep_ids])),
                    )
                    sys.exit(1)

                for replicate in sorted(sample_mapping_dict[sample].keys()):
                    for idx, val in enumerate(sample_mapping_dict[sample][replicate]):
                        control = "_REP".join(val[-1].split("_REP")[:-1])
                        control_replicate = val[-1].split("_REP")[-1]
                        if control and (
                            control not in sample_mapping_dict.keys()
                            or int(control_replicate) not in sample_mapping_dict[control].keys()
                        ):
                            print_error(
                                f"Control identifier and replicate has to match a provided sample identifier and replicate!",
                                "Control",
                                val[-1],
                            )

                    ## Write to file
                    for idx in range(len(sample_mapping_dict[sample][replicate])):
                        bam_info = sample_mapping_dict[sample][replicate][idx]
                        sample_id = "{}_REP{}".format(sample, replicate)
                        fout.write(",".join([sample_id] + bam_info) + "\n")

    else:
        print_error(f"No entries to process!", "Samplesheet: {file_in}")


def main(args=None):
    args = parse_args(args)
    check_bam_samplesheet(args.FILE_IN, args.FILE_OUT)


if __name__ == "__main__":
    sys.exit(main())
