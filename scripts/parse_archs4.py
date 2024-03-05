import f4
import gzip
import os
import shutil
import sys

sample_file_path = sys.argv[1]
expr_file_path = sys.argv[2]
out_f4_file_path = sys.argv[3]

def save_sample_info_to_f4():
    # Get characteristic info
    characteristics_series = {}
    with gzip.open(sample_file_path, compresslevel=1) as sample_file:
        header_items = sample_file.readline().decode().rstrip("\n").split("\t")

        for line in sample_file:
            line_items = line.decode().rstrip("\n").split("\t")

            characteristics = line_items[1].strip()
            series_id = line_items[22]

            for characteristic in characteristics.split(";"):
                characteristic_items = [x.strip().lower() for x in characteristic.split(": ")]

                if len(characteristic_items) < 2 or characteristic_items[0] in ["", "description"] or characteristic_items[0].startswith("http"):
                    continue

                if characteristic_items[0] in characteristics_series:
                    characteristics_series[characteristic_items[0]].add(series_id)
                else:
                    characteristics_series[characteristic_items[0]] = set()

    # Filter the characteristics to those that are most common
    keys_to_keep = []

    for key, series_ids in sorted(characteristics_series.items()):
        if len(series_ids) > 100:
            keys_to_keep.append(key)

    keys_to_keep = sorted(keys_to_keep)

    # Create dictionary with cleaned metadata
    with gzip.open(sample_file_path, compresslevel=1) as sample_file:
        header_items = sample_file.readline().decode().rstrip("\n").split("\t")

        with gzip.open(tmp_tsv_file_path, "w", compresslevel=1) as tmp_tsv_file:
            tmp_tsv_file.write(("\t".join(keys_to_keep + header_items[0:1] + header_items[2:]) + "\n").encode())

            for line in sample_file:
                line_items = line.decode().rstrip("\n").split("\t")
                characteristics = line_items[1].strip()

                characteristics_dict = {}
                for characteristic in characteristics.split(";"):
                    characteristic_items = [x.strip().lower() for x in characteristic.split(": ")]

                    if len(characteristic_items) < 2:
                        continue

                    characteristics_dict[characteristic_items[0]] = characteristic_items[1]

                characteristics_items = []
                for key in keys_to_keep:
                    if key in characteristics_dict:
                        characteristics_items.append(characteristics_dict[key])
                    else:
                        characteristics_items.append("NA")

                # The first column has the characteristics that have no been split out.
                tmp_tsv_file.write(("\t".join(characteristics_items + line_items[0:1] + line_items[2:]) + "\n").encode())

    f4.convert_delimited_file(tmp_tsv_file_path, tmp_sample_f4_file_path, compression_type="zstd", num_parallel=16, tmp_dir_path="data/archs4/f4_tmp", verbose=True)

    shutil.rmtree("data/archs4/f4_tmp")

tmp_tsv_file_path = "data/archs4/tmp.tsv.gz"
tmp_sample_f4_file_path = "data/archs4/sample.f4"
tmp_expr_f4_file_path = "data/archs4/expr.f4"
tmp_expr_transposed_f4_file_path = "data/archs4/expr_transposed.f4"

#save_sample_info_to_f4()

# This code renames the first column.
#with gzip.open(expr_file_path, compresslevel=1) as expr_file:
#    header_items = expr_file.readline().rstrip(b"\n").split(b"\t")
#    header_items[0] = b"geo_accession"
#
#    with gzip.open(tmp_tsv_file_path, "w", compresslevel=1) as tmp_tsv_file:
#        tmp_tsv_file.write(b"\t".join(header_items) + b"\n")
#
#        for line_i, line in enumerate(expr_file):
#            if line_i % 1000 == 0:
#                print(line_i, flush=True)
#            tmp_tsv_file.write(line)

f4.convert_delimited_file(tmp_tsv_file_path, tmp_expr_f4_file_path, compression_type="zstd", num_parallel=16, tmp_dir_path="data/archs4/f4_tmp", verbose=True)
sys.exit()

#shutil.rmtree("data/archs4/f4_tmp")

f4.transpose(tmp_expr_f4_file_path, tmp_expr_transposed_f4_file_path, num_parallel=16, verbose=True)
f4.inner_join(tmp_sample_f4_file_path, tmp_expr_transposed_f4_file_path, join_column="geo_accession", f4_dest_file_path=out_f4_file_path, num_parallel=16, verbose=True)
f4.build_indexes(out_f4_file_path, index_columns=["age", "cell type", "tissue", "sex"], verbose=True)

os.remove(tmp_tsv_file_path)
os.remove(tmp_sample_f4_file_path)
os.remove(tmp_expr_f4_file_path)
os.remove(tmp_expr_transposed_f4_file_path)
