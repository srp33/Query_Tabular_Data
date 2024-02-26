import gzip
import h5py
import numpy as np
import pandas as pd
import sys

in_file_path = sys.argv[1]
out_samples_file_path = sys.argv[2]
out_expr_file_path = sys.argv[3]

########################################################
# Parse sample data
########################################################

samples_h5 = h5py.File(in_file_path)["meta"]["samples"]

sample_keys = sorted(list(samples_h5.keys()))
sample_dict = {}
for sample_key in sample_keys:
    sample_dict[sample_key] = [x.replace(b"\t", b";") if isinstance(x, bytes) else str(x).encode() for x in samples_h5[sample_key]]

with gzip.open(out_samples_file_path, "w") as out_samples_file:
    out_samples_file.write(("\t".join(sample_keys)).encode() + b"\n")

    num_samples = len(sample_dict[sample_keys[0]])

    for i in range(num_samples):
        out_items = [sample_dict[sample_key][i] for sample_key in sample_keys]
        out_samples_file.write(b"\t".join(out_items) + b"\n")

########################################################
# Parse expression data
########################################################

transcripts_h5 = h5py.File(in_file_path)["meta"]["transcripts"]
ensembl_ids = [x for x in transcripts_h5["ensembl_id"]]
gene_symbols = [x for x in transcripts_h5["symbol"]]
gene_biotypes = [x for x in transcripts_h5["biotype"]]

expr_h5 = h5py.File(in_file_path)["data"]["expression"]

with gzip.open(out_expr_file_path, "w") as out_file:
    out_file.write(b"\t".join([b"ensembl_id"] + sample_dict["geo_accession"]) + b"\n")

    chunk_size = 100
    for i in range(0, expr_h5.shape[0], chunk_size):
        print(f"Retrieving expression data for row {i}", flush=True)

        end_i = min([i + chunk_size, expr_h5.shape[0]])
        chunk = np.array(expr_h5[i:end_i,:]).tolist()

        for row in chunk:
            out_items = [ensembl_ids.pop(0)] + [str(x).encode() for x in row]
            out_file.write(b"\t".join(out_items) + b"\n")
