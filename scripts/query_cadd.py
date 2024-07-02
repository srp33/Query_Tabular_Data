import f4
import operator
import sys

in_file_path = sys.argv[1]
num_parallel = int(sys.argv[2])
out_file_path = sys.argv[3]

fltr = f4.AndFilter(
            f4.AndFilter(
                f4.StringFilter("#Chrom", operator.eq, "17"),
                f4.IntRangeFilter("Pos", 7661779, 7687546),
            ),
            f4.StringFilter("Consequence", operator.eq, "STOP_GAINED"),
            f4.FloatFilter("PHRED", operator.gt, 40.0)
)
#index_columns=[["#Chrom", "Pos"], "Type", "AnnoType", "Consequence", "PHRED"]
select_columns = None
tmp_dir_path = "data/cadd/tmp"

f4.query(in_file_path, fltr=fltr, select_columns=select_columns, out_file_path=out_file_path, num_parallel=num_parallel, tmp_dir_path=tmp_dir_path, use_memory_mapping=True)

#print(f"out_file_path: {out_file_path}")
