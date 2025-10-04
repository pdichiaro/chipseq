#!/usr/bin/env python3

"""
Generate intersection file for condition-level UpSet plots.
This script creates a file compatible with plot_peak_intersect.r showing
overlaps between different conditions for the same antibody.
"""

import sys
import argparse
from collections import defaultdict

def main():
    parser = argparse.ArgumentParser(description='Generate condition intersection data for UpSet plot')
    parser.add_argument('merged_file', help='Merged peaks file with condition tags')
    parser.add_argument('condition_names', help='Comma-separated list of condition names')
    parser.add_argument('output_file', help='Output intersect file')
    args = parser.parse_args()
    
    conditions = args.condition_names.split(',')
    condition_set = set(conditions)
    
    # Dictionary to count peak intersections
    # Key: frozenset of conditions, Value: count
    intersect_counts = defaultdict(int)
    
    # Read merged peaks file
    with open(args.merged_file, 'r') as f:
        for line in f:
            fields = line.strip().split('\t')
            if len(fields) < 6:
                continue
                
            # Column 5 (index 5) contains comma-separated peak names
            # Format: CONDITION_Interval_N,CONDITION2_Interval_M,...
            peak_names = fields[5].split(',')
            
            # Extract condition names from peak names
            peak_conditions = set()
            for peak_name in peak_names:
                # Peak name format: CONDITION_Interval_N or CONDITION_...
                # Extract the first part before _Interval or before _peaks
                parts = peak_name.split('_')
                if len(parts) > 0:
                    # Try to match against known conditions
                    for cond in conditions:
                        if peak_name.startswith(cond + '_'):
                            peak_conditions.add(cond)
                            break
            
            # Only count if we found valid conditions
            if peak_conditions:
                intersect_counts[frozenset(peak_conditions)] += 1
    
    # Write output in UpSetR compatible format
    # Format: condition1&condition2&condition3  count
    with open(args.output_file, 'w') as f:
        # Sort by count (descending), then by number of conditions, then alphabetically
        sorted_intersects = sorted(
            intersect_counts.items(),
            key=lambda x: (-x[1], -len(x[0]), '&'.join(sorted(x[0])))
        )
        
        for cond_set, count in sorted_intersects:
            cond_list = sorted(cond_set)
            f.write(f"{'&'.join(cond_list)}\t{count}\n")
    
    print(f"Generated intersection file with {len(intersect_counts)} unique combinations")
    for cond_set, count in sorted_intersects[:5]:  # Show top 5
        print(f"  {'&'.join(sorted(cond_set))}: {count} peaks")

if __name__ == '__main__':
    main()
