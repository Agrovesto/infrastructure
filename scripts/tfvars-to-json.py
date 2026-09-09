#!/usr/bin/env python3
"""Convert literal, non-secret .tfvars to JSON for the GitHub TF_VARS_JSON variable."""
import argparse
import json
import hcl2

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("file")
args = parser.parse_args()
with open(args.file) as handle:
    print(json.dumps(hcl2.load(handle), indent=2))
