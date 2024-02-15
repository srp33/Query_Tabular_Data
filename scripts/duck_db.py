import duckdb
import string
import sys

query_type = sys.argv[1]
in_file_path = sys.argv[2]
out_file_path = sys.argv[3]
discrete_query_col_name = sys.argv[4]
numeric_query_col_name = sys.argv[5]
col_names_to_keep = sys.argv[6]

if col_names_to_keep == "all_columns":
    print(in_file_path)
    with open(in_file_path) as in_file:
        all_col_names = in_file.readline().rstrip("\n").split("\t")
else:
    all_col_names = [discrete_query_col_name, numeric_query_col_name] + col_names_to_keep.split(",")

rel = duckdb.from_csv_auto(in_file_path)

if query_type == "simple":
    rel = rel.filter(f"({discrete_query_col_name} == 'AM' or {discrete_query_col_name} == 'NZ') and {numeric_query_col_name} >= 0.1").project(",".join(all_col_names))
elif query_type == "startsendswith":
    discrete_values_A = ",".join([f"'A{x}'" for x in string.ascii_uppercase])
    discrete_values_Z = ",".join([f"'{x}Z'" for x in string.ascii_uppercase])
    rel = rel.filter(f"({discrete_query_col_name} in ({discrete_values_A}) or {discrete_query_col_name} in ({discrete_values_Z})) and {numeric_query_col_name} >= 0.1").project(",".join(all_col_names))

with open(out_file_path, "w") as out_file:
    out_file.write("\t".join(all_col_names) + "\n")

    for row in rel.fetchall():
        out_file.write("\t".join([str(x) for x in row]) + "\n")
