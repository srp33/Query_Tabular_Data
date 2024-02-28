import f4
import sys

tsv_file_path = sys.argv[1]
num_parallel = int(sys.argv[2])
compression_type = None if sys.argv[3] == "None" else sys.argv[3]
index_columns = sys.argv[4].split(";")
out_file_path = sys.argv[5]

f4.convert_delimited_file(tsv_file_path, out_file_path, index_columns=index_columns, compression_type=compression_type, num_parallel=num_parallel)
#print(f4.get_indexes(out_file_path))
