import msgpack
import mmap
import re
import sys
from Helper import *

file_path = sys.argv[1]
row_indices_file_path = sys.argv[2]
col_indices_file_path = sys.argv[3]
out_file_path = sys.argv[4]
memory_map = True

def find_col_coords(col_indices):
    for col_index in col_indices:
        start_pos = col_index * max_column_coord_length
        next_start_pos = start_pos + max_column_coord_length

        yield [int(x) for x in cc_map_file[start_pos:next_start_pos].rstrip().split(b",")]

def parse_row_values(row_index, col_coords):
    row_start = row_index * line_length

    for coords in col_coords:
        yield data_map_file[row_start + coords[0]:row_start + coords[0] + coords[1]].rstrip()

select_row_indices = [x for x in getColIndicesToQuery(row_indices_file_path, memory_map)]
select_col_indices = [x for x in getColIndicesToQuery(col_indices_file_path, memory_map)]

with open(file_path + ".ll", 'rb') as ll_file:
    line_length = int(ll_file.read().rstrip())

with open(file_path + ".mccl", 'rb') as mccl_file:
    max_column_coord_length = int(mccl_file.read().rstrip())

with open(file_path + ".cc", 'rb') as cc_file:
    cc_map_file = mmap.mmap(cc_file.fileno(), 0, prot=mmap.PROT_READ)

    with open(file_path, 'rb') as data_file:
        data_map_file = mmap.mmap(data_file.fileno(), 0, prot=mmap.PROT_READ)

        with open(out_file_path, 'wb') as out_file:
            col_coords = list(find_col_coords(select_col_indices))

            out_lines = []
            chunk_size = 1000

            for row_index in select_row_indices:
                out_lines.append(b"\t".join(parse_row_values(row_index, col_coords)).rstrip())

                if len(out_lines) % chunk_size == 0:
                    out_file.write(b"\n".join(out_lines) + b"\n")
                    out_lines = []

            if len(out_lines) > 0:
                out_file.write(b"\n".join(out_lines) + b"\n")

        data_map_file.close()
    cc_map_file.close()
