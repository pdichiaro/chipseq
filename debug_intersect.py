#!/usr/bin/env python3

"""
Debug script to test macs2_merged_expand.py name parsing logic
"""

# Simulate peak names from condition consensus files
test_names = [
    "WT_BCATENIN_peak_1",
    "NAIVE_BCATENIN_peak_2", 
    "KD_BCATENIN_peak_3",
    "CTRL_BCATENIN_peak_4"
]

print("Testing name extraction logic:")
print("=" * 60)

for name in test_names:
    # This is what macs2_merged_expand.py does (line 120)
    sID = "_".join(name.split("_")[:-2])
    print(f"Original name: {name:30} -> Extracted: {sID}")
    
    # Then it tries to get group ID (line 121)
    gID = "_".join(sID.split("_")[:-1])
    print(f"  -> Group ID: {gID}")
    print()

print("\nPotential problem:")
print("If peak names are just 'WT_BCATENIN_peak_1', the extraction")
print("removes '_peak_1' leaving 'WT_BCATENIN', which is correct.")
print("\nBut if there are other suffixes or formats, this could break!")
