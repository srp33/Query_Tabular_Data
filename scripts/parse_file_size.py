import glob
import math
import os
import sys

file_pattern = sys.argv[1]
error_output = sys.argv[2] # This is what the bash script retrieved.
out_file_path = sys.argv[3]
include_newline = sys.argv[4] == "True"

total_size = 0

with open(out_file_path, "a") as out_file:
    if error_output == "":
        total_size = 0
        for file_path in glob.glob(file_pattern):
            total_size += os.path.getsize(file_path)

        out_file.write(f"\t{math.ceil(total_size / 1024)}")

    else:
        out_file.write(f"\t{error_output}")

    if include_newline:
        out_file.write("\n")
