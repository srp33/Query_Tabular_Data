suppressPackageStartupMessages(library(arrow))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(readr))

args = commandArgs(trailingOnly=TRUE)

query_type = args[1]
in_file_path = args[2]
out_file_path = args[3]
discrete_query_col_name = args[4]
numeric_query_col_name = args[5]
col_names_to_keep = args[6]

if (col_names_to_keep == "all_columns") {
    data = suppressWarnings(suppressMessages(read_tsv_arrow(in_file_path)))
} else {
    col_names_to_keep2 = strsplit(col_names_to_keep, ",")[[1]]
    data = suppressWarnings(suppressMessages(read_tsv_arrow(in_file_path, col_select=all_of(c(discrete_query_col_name, numeric_query_col_name, col_names_to_keep2)))))
}

# It appears that there is no way to write a tsv file with arrow.
if (query_type == "simple") {
    output = filter(data, (!!sym(discrete_query_col_name)) %in% c('AM', 'NZ') & (!!sym(numeric_query_col_name) >= 0.1))

    if (col_names_to_keep != "all_columns") {
        output = select(output, all_of(col_names_to_keep2))
    }
} else {
    if (query_type == "startsendswith") {
        output = filter(data, (grepl("A\\w", (!!sym(discrete_query_col_name))) | grepl("\\wZ", (!!sym(discrete_query_col_name)))) & (!!sym(numeric_query_col_name) >= 0.1))

        if (col_names_to_keep != "all_columns") {
            output = select(output, all_of(col_names_to_keep2))
        }
    }
}

write_tsv(output, out_file_path)
