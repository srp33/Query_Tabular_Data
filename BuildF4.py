import f4py
import glob
import os
import sys

in_file_path = sys.argv[1]
out_file_prefix = sys.argv[2]
num_processes = int(sys.argv[3])
num_cols_per_chunk = int(sys.argv[4])
index_columns = sys.argv[5].split(",")
compression_level = 22
tmp_dir_path = sys.argv[6]

f4_file_path = f"{out_file_prefix}.f4"

# Clean up data files if they already exist
for file_path in glob.glob(f"{f4_file_path}*"):
    os.unlink(file_path)

f4py.Builder(verbose=True).convert_delimited_file(in_file_path, f4_file_path, index_columns=index_columns, delimiter="\t", compression_level=compression_level, num_processes=num_processes, num_cols_per_chunk=num_cols_per_chunk, tmp_dir_path=tmp_dir_path, cache_intermediate_results=True)
