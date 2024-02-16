#! /bin/bash

# Prior benchmarks
  #https://pythonspeed.com/articles/pandas-read-csv-fast/ (shows examples of pyarrow and pyparquet)
  #https://www.danielecook.com/speeding-up-reading-and-writing-in-r/
  #https://cran.r-project.org/web/packages/vroom/vignettes/benchmarks.html
  #https://data.nozav.org/post/2019-r-data-frame-benchmark/ (multiple formats)

# Interpreting output of time command:
#   https://stackoverflow.com/questions/556405/what-do-real-user-and-sys-mean-in-the-output-of-time1

set -o errexit

#######################################################
# Create directories
#######################################################

mkdir -p data results scripts

#######################################################
# Set up Docker
#######################################################

pythonImage=tab_bench_python
rImage=tab_bench_r
rustImage=tab_bench_rust

currentDir="$(pwd)"
tmpDir=/tmp/build_docker

function buildDockerImage {
    dockerFileName=$1
    otherDir="$2"

    rm -rf $tmpDir
    mkdir -p $tmpDir

    dockerFilePath=Dockerfiles/$dockerFileName

    cp $dockerFilePath $tmpDir/

    if [[ "$otherDir" != "" ]]
    then
        cp -r "$otherDir"/* $tmpDir/
    fi

    cd $tmpDir
    docker build -t $dockerFileName -f $dockerFileName .
    cd $currentDir
}

#buildDockerImage tab_bench_python
#buildDockerImage tab_bench_r
#buildDockerImage tab_bench_rust $currentDir/Rust

#baseDockerCommand="docker run --rm --user $(id -u):$(id -g) -v $(pwd)/data:/data -v $(pwd)/results:/results -v $(pwd)/scripts:/scripts -v /tmp:/tmp"
baseDockerCommand="docker run -i -t --rm --user $(id -u):$(id -g) -v $(pwd)/data:/data -v $(pwd)/results:/results -v $(pwd)/scripts:/scripts -v /tmp:/tmp"
#baseDockerCommand="docker run -d --rm --user $(id -u):$(id -g) -v $(pwd)/data:/data -v $(pwd)/results:/results -v $(pwd)/scripts:/scripts -v /tmp:/tmp"
pythonDockerCommand="$baseDockerCommand $pythonImage"
rDockerCommand="$baseDockerCommand $rImage"
rustDockerCommand="$baseDockerCommand $rustImage"

#######################################################
# Create TSV files
#######################################################

small="10 90 1000"
tall="100 900 1000000"
wide="100000 900000 1000"

# Small file
#$pythonDockerCommand python scripts/build_tsv.py $small data/${small// /_}.tsv
# Tall, narrow file
#$pythonDockerCommand python scripts/build_tsv.py $tall data/${tall// /_}.tsv
# Short, wide file
#$pythonDockerCommand python scripts/build_tsv.py $wide data/${wide// /_}.tsv

#######################################################
# Convert files to other formats.
#######################################################

function convertTSV {
  numDiscrete=$1
  numNumeric=$2
  numRows=$3
  dockerCommand="$4"
  commandPrefix="$5"
  outExtension=$6
  resultFile=$7

  dataFile=data/${numDiscrete}_${numNumeric}_$numRows.tsv
  outFile=data/${numDiscrete}_${numNumeric}_${numRows}.${outExtension}

#  if [ -f $outFile ]
#  then
#    echo $outFile already exists.
#  else
    echo -n -e "${outExtension}\t$numDiscrete\t$numNumeric\t$numRows\t" >> $resultFile
  
    command="${commandPrefix} $dataFile $outFile"

#    echo $command
#    $dockerCommand $command
    $dockerCommand /usr/bin/time --verbose $command &> /tmp/result
    $pythonDockerCommand python scripts/parse_time_memory.py /tmp/result >> $resultFile
    echo >> $resultFile
#  fi
}

conversionsResultFile=results/conversions.tsv

#echo -e "Extension\tNumDiscrete\tNumNumeric\tNumRows\tWallClockSeconds\tUserSeconds\tSystemSeconds\tMaxMemoryUsed_kilobytes" > $conversionsResultFile

#for size in "$small" "$tall" "$wide"
#for size in "$small"
#for size in "$tall"
#for size in "$wide"
#do
#  convertTSV $size "${rDockerCommand}" "Rscript scripts/convert_to_parquet.R" prq $conversionsResultFile
#  convertTSV $size "${rDockerCommand}" "Rscript scripts/convert_to_arrow.R" arw $conversionsResultFile
#  convertTSV $size "${rDockerCommand}" "Rscript scripts/convert_to_feather.R" fthr $conversionsResultFile
#  convertTSV $size "${rDockerCommand}" "Rscript scripts/convert_to_fst.R" fst $conversionsResultFile
#  convertTSV $size "${pythonDockerCommand}" "python scripts/convert_to_fwf2.py" fwf2 $conversionsResultFile
#done

#NOTE: hdf5 fails when trying to write *wide* files in "table" mode. We can only read specific columns (rather than the whole) file in table mode, not fixed mode.
#for size in "$small" "$tall"
#for size in "$small"
#do
#  convertTSV $size "${pythonDockerCommand}" "python scripts/convert_to_hdf5.py" hdf5 $conversionsResultFile
#done

#######################################################
# Query files. Filter based on values in 2 columns.
#   Then select other columns.
#######################################################

function queryFile {
  iteration=$1
  numDiscrete=$2
  numNumeric=$3
  numRows=$4
  fileFormat="$5"
  compressionType="$6"
  programmingLanguage="$7"
  analysisType="$8"
  numThreads="$9"
  dockerCommand="${10}"
  commandPrefix="${11}"
  queryType=${12}
  columns=${13}
  isMaster=${14}
  inFileExtension=${15}
  inFileNameSuffix=${16}
  resultFile=${17}

  dataFile=data/${numDiscrete}_${numNumeric}_${numRows}${inFileNameSuffix}.${inFileExtension}
  outFile=/tmp/benchmark_files/${numDiscrete}_${numNumeric}_${numRows}_${queryType}_${columns}

  rm -f $outFile

  echo -n -e "${iteration}\t${fileFormat}\t${compressionType}\t${programmingLanguage}\t${analysisType}\t${numThreads}\t${commandPrefix}\t$queryType\t$columns\t$numDiscrete\t$numNumeric\t$numRows\t" >> $resultFile

  colNamesToKeep="all_columns"
  if [[ "$columns" == "firstlast_columns" ]]
  then
      colNamesToKeep="Discrete1,Discrete${numDiscrete},Numeric1,Numeric${numNumeric}"
  fi
  
  command="${commandPrefix} $queryType $dataFile $outFile Discrete2 Numeric2 $colNamesToKeep"

  echo Running query for ${iteration}, ${numDiscrete}, ${numNumeric}, ${numRows}, ${commandPrefix}, ${queryType}, ${columns}

#  $dockerCommand $command
  $dockerCommand /usr/bin/time --verbose $command &> /tmp/result
  $pythonDockerCommand python scripts/parse_time_memory.py /tmp/result >> $resultFile
  $pythonDockerCommand python scripts/parse_file_size.py $outFile >> $resultFile
  echo >> $resultFile

  masterFile=/tmp/benchmark_files/${numDiscrete}_${numNumeric}_${numRows}_${queryType}_${columns}_master

  if [[ "$isMaster" == "False" ]]
  then
      if [ -f $outFile ]
      then
          echo Checking output for ${iteration}, ${numDiscrete}, ${numNumeric}, ${numRows}, ${commandPrefix}, ${queryType}, ${columns} in ${outFile}
          python CheckOutput.py $outFile $masterFile
      else
          echo No output for ${iteration}, ${numDiscrete}, ${numNumeric}, ${numRows}, ${commandPrefix}, ${queryType}, ${columns}
      fi
  else
    echo Saving master file for ${iteration}, ${numDiscrete}, ${numNumeric}, ${numRows}, ${commandPrefix}, ${queryType}, ${columns}
    mv $outFile $masterFile
    echo "  Done"
  fi
}

#rm -rf /tmp/benchmark_files
mkdir -p /tmp/benchmark_files

queryResultFile=results/queries.tsv

echo -e "Iteration\tFileFormat\tCompressionType\tProgrammingLanguage\tAnalysisType\tNumThreads\tCommandPrefix\tQueryType\tColumns\tNumDiscrete\tNumNumeric\tNumRows\tWallClockSeconds\tUserSeconds\tSystemSeconds\tMaxMemoryUsed_kb\tOutputFileSize_kb" > $queryResultFile

#for iteration in {1..5}
#for iteration in {1..1}
#do
#    for queryType in simple startsendswith
#    for queryType in simple
#    for queryType in startsendswith
#    do
#        for size in "$small" "$tall" "$wide"
#        for size in "$small"
#        for size in "$tall"
#        for size in "$wide"
#        do
#            for columns in firstlast_columns all_columns
#            for columns in firstlast_columns
#            for columns in all_columns
#            do
#                isMaster=False
#                if [[ "$iteration" == "1" ]]
#                then
#                    isMaster=True
#                fi
#
#                queryFile $iteration $size TSV None Python baseline 1 "${pythonDockerCommand}" "python scripts/line_by_line.py standard_io" $queryType $columns $isMaster tsv "" $queryResultFile
#
#                queryFile $iteration $size TSV None Python "baseline - memory mapping" 1 "${pythonDockerCommand}" "python scripts/line_by_line.py memory_map" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None Python awk 1 "${pythonDockerCommand}" "python scripts/awk.py awk" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None Python gawk 1 "${pythonDockerCommand}" "python scripts/awk.py gawk" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None Python nawk 1 "${pythonDockerCommand}" "python scripts/awk.py nawk" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None R "read.table" 1 "${rDockerCommand}" "Rscript scripts/base.R" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None R "readr - not lazy" 1 "${rDockerCommand}" "Rscript scripts/readr.R 1_thread,not_lazy" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None R "readr - not lazy" 8 "${rDockerCommand}" "Rscript scripts/readr.R 8_threads,not_lazy" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None R "readr - lazy" 8 "${rDockerCommand}" "Rscript scripts/readr.R 8_threads,lazy" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None R "vroom - no altrep" 1 "${rDockerCommand}" "Rscript scripts/vroom.R 1_thread,no_altrep" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None R "vroom - no altrep" 8 "${rDockerCommand}" "Rscript scripts/vroom.R 8_threads,no_altrep" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None R "vroom - altrep" 1 "${rDockerCommand}" "Rscript scripts/vroom.R 1_thread,altrep" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None R "vroom - altrep" 8 "${rDockerCommand}" "Rscript scripts/vroom.R 8_threads,altrep" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None R "fread" 1 "${rDockerCommand}" "Rscript scripts/fread.R 1_thread" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None R "fread" 8 "${rDockerCommand}" "Rscript scripts/fread.R 8_threads" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None R "ff" 1 "${rDockerCommand}" "Rscript scripts/ff.R" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None R "arrow" 1 "${rDockerCommand}" "Rscript scripts/arrow_csv.R" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None Python "pandas - c engine - standard io" 1 "${pythonDockerCommand}" "python scripts/pandas_csv.py c_engine,standard_io" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None Python "pandas - c engine - memory mapping" 1 "${pythonDockerCommand}" "python scripts/pandas_csv.py c_engine,memory_map" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None Python "pandas - python engine - standard io" 1 "${pythonDockerCommand}" "python scripts/pandas_csv.py python_engine,standard_io" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None Python "pandas - python engine - memory mapping" 1 "${pythonDockerCommand}" "python scripts/pandas_csv.py python_engine,memory_map" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size TSV None Python "pandas - pyarrow engine - standard io" 1 "${pythonDockerCommand}" "python scripts/pandas_csv.py pyarrow_engine,standard_io" $queryType $columns False tsv "" $queryResultFile
#                # INFO: pyarrow does not support the 'memory_map' option.
#                queryFile $iteration $size TSV None Python "DuckDB" 1 "${pythonDockerCommand}" "python scripts/duck_db.py" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size HDF5 None Python "pandas" 1 "${pythonDockerCommand}" "python scripts/pandas_hdf5.py" $queryType $columns False hdf5 "" $queryResultFile
#                queryFile $iteration $size TSV None Python "polars" 1 "${pythonDockerCommand}" "python scripts/polars_csv.py" $queryType $columns False tsv "" $queryResultFile
#                queryFile $iteration $size fst None R "fst" 1 "${rDockerCommand}" "Rscript scripts/fst.R" $queryType $columns False fst "" $queryResultFile
#                queryFile $iteration $size Feather None R "feather" 1 "${rDockerCommand}" "Rscript scripts/feather.R" $queryType $columns False fthr "" $queryResultFile
#                queryFile $iteration $size "Apache Arrow" None R "arrow" 1 "${rDockerCommand}" "Rscript scripts/arrow.R feather2" $queryType $columns False arw "" $queryResultFile
#                queryFile $iteration $size "Apache Parquet" None R "arrow" 1 "${rDockerCommand}" "Rscript scripts/arrow.R parquet" $queryType $columns False prq "" $queryResultFile
#                queryFile $iteration $size FWF None Python "basic" 1 "${pythonDockerCommand}" "python scripts/fwf2.py" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF None Rust "basic" 1 "${rustDockerCommand}" "/Rust/fwf2/target/release/main" $queryType $columns False fwf2 "" $queryResultFile
#            done
#        done
#    done
#done

############################################################
# Build compressed versions of the fixed-width files using
# a variety of compression algorithms. Each line in the data
# is compressed individually.
############################################################

function compressLines {
  resultFile=$1
  numDiscrete=$2
  numNumeric=$3
  numRows=$4
  method=$5
  level=$6

  inFile=data/${numDiscrete}_${numNumeric}_${numRows}.fwf2
  outFile=data/compressed/${numDiscrete}_${numNumeric}_${numRows}.fwf2.${method}

  if [[ "$level" != "NA" ]]
  then
    outFile=${outFile}_${level}
  fi

  command="python3 scripts/compress_lines.py $inFile $numRows $method $level $outFile"
  echo Running "$command"

  echo -n -e "${numDiscrete}\t${numNumeric}\t${numRows}\t${method}\t${level}\t" >> $resultFile

#  $pythonDockerCommand $command
  $pythonDockerCommand /usr/bin/time --verbose $command &> /tmp/result
  $pythonDockerCommand python scripts/parse_time_memory.py /tmp/result >> $resultFile
  $pythonDockerCommand python scripts/parse_file_size.py ${outFile}* >> $resultFile
  echo >> $resultFile
}

function compressLinesAll {
    resultFile=$1
    size="$2"

    compressLines $resultFile $size bz2 1
    compressLines $resultFile $size bz2 5
    compressLines $resultFile $size bz2 9
    compressLines $resultFile $size gz 1
    compressLines $resultFile $size gz 5
    compressLines $resultFile $size gz 9
    compressLines $resultFile $size lzma NA
    compressLines $resultFile $size snappy NA
    compressLines $resultFile $size zstd 1
    compressLines $resultFile $size zstd 5
    compressLines $resultFile $size zstd 9
    compressLines $resultFile $size zstd 22
    compressLines $resultFile $size lz4 0
    compressLines $resultFile $size lz4 5
    compressLines $resultFile $size lz4 10
    compressLines $resultFile $size lz4 16
}

mkdir -p data/compressed

compressLinesResultFile=results/compress_lines.tsv

#echo -e "NumDiscrete\tNumNumeric\tNumRows\tMethod\tLevel\tWallClockSeconds\tUserSeconds\tSystemSeconds\tMaxMemoryUsed_kb\tOutputFileSize_kb" > $compressLinesResultFile

#compressLinesAll $compressLinesResultFile "$small"
#compressLinesAll $compressLinesResultFile "$tall"
#compressLinesAll $compressLinesResultFile "$wide"

############################################################
# Measure how quickly we can query the files that have
# been compressed line-by-line.
############################################################

#for iteration in {1..5}
#for iteration in {1..1}
#do
#    for queryType in simple startsendswith
#    for queryType in simple
#    for queryType in startsendswith
#    do
#        for size in "$small" "$tall" "$wide"
#        for size in "$small"
#        for size in "$tall"
#        for size in "$wide"
#        do
#            for columns in firstlast_columns all_columns
#            for columns in firstlast_columns
#            for columns in all_columns
#            do
#                queryFile $iteration $size FWF bz2__1 Python "basic" 1 "${pythonDockerCommand}" "python scripts/fwf2_cmpr.py bz2 1" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF bz2__5 Python "basic" 1 "${pythonDockerCommand}" "python scripts/fwf2_cmpr.py bz2 5" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF bz2__9 Python "basic" 1 "${pythonDockerCommand}" "python scripts/fwf2_cmpr.py bz2 9" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF gz__1 Python "basic" 1 "${pythonDockerCommand}" "python scripts/fwf2_cmpr.py gz 1" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF gz__5 Python "basic" 1 "${pythonDockerCommand}" "python scripts/fwf2_cmpr.py gz 5" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF gz__9 Python "basic" 1 "${pythonDockerCommand}" "python scripts/fwf2_cmpr.py gz 9" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF lzma Python "basic" 1 "${pythonDockerCommand}" "python scripts/fwf2_cmpr.py lzma NA" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF snappy Python "basic" 1 "${pythonDockerCommand}" "python scripts/fwf2_cmpr.py snappy NA" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF zstd__1 Python "basic" 1 "${pythonDockerCommand}" "python scripts/fwf2_cmpr.py zstd 1" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF zstd__1 Rust "basic" 1 "${rustDockerCommand}" "/Rust/fwf2_cmpr/target/release/main zstd 1" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF zstd__5 Python "basic" 1 "${pythonDockerCommand}" "python scripts/fwf2_cmpr.py zstd 5" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF zstd__5 Rust "basic" 1 "${rustDockerCommand}" "/Rust/fwf2_cmpr/target/release/main zstd 5" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF zstd__9 Python "basic" 1 "${pythonDockerCommand}" "python scripts/fwf2_cmpr.py zstd 9" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF zstd__9 Rust "basic" 1 "${rustDockerCommand}" "/Rust/fwf2_cmpr/target/release/main zstd 9" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF zstd__22 Python "basic" 1 "${pythonDockerCommand}" "python scripts/fwf2_cmpr.py zstd 22" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF zstd__22 Rust "basic" 1 "${rustDockerCommand}" "/Rust/fwf2_cmpr/target/release/main zstd 22" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF lz4__0 Python "basic" 1 "${pythonDockerCommand}" "python scripts/fwf2_cmpr.py lz4 0" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF lz4__5 Python "basic" 1 "${pythonDockerCommand}" "python scripts/fwf2_cmpr.py lz4 5" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF lz4__10 Python "basic" 1 "${pythonDockerCommand}" "python scripts/fwf2_cmpr.py lz4 10" $queryType $columns False fwf2 "" $queryResultFile
#                queryFile $iteration $size FWF lz4__16 Python "basic" 1 "${pythonDockerCommand}" "python scripts/fwf2_cmpr.py lz4 16" $queryType $columns False fwf2 "" $queryResultFile
#            done
#        done
#    done
#done

############################################################
# Build compressed versions of the fixed-width files that
# have a transposed version of the data. Each line is 
# compressed individually.
############################################################

function transposeAndCompressLines {
  resultFile=$1
  numDiscrete=$2
  numNumeric=$3
  numRows=$4
  method=$5
  level=$6

  inFile1=data/${numDiscrete}_${numNumeric}_${numRows}.fwf2
  inFile2=data/compressed/${numDiscrete}_${numNumeric}_${numRows}.fwf2.${method}_${level}
  outFile1=data/transposed/${numDiscrete}_${numNumeric}_${numRows}.fwf2
  outFile2=data/transposed_and_compressed/${numDiscrete}_${numNumeric}_${numRows}.fwf2.${method}_${level}
  transposedNumRows=$((numDiscrete + numNumeric))

  if [ ! -f $outFile1 ]
  then
    echo Transpose $inFile1 to $outFile1
    $pythonDockerCommand python3 scripts/transpose_fwf2.py $inFile1 $outFile1
  fi

  if [ ! -f $outFile2 ]
  then
    echo Compressing $outFile1 to $outFile2
    $pythonDockerCommand python3 scripts/compress_lines.py $outFile1 $transposedNumRows $method $level $outFile2
  fi

  echo -n -e "${numDiscrete}\t${numNumeric}\t${numRows}\t${method}\t${level}" >> $resultFile
  $pythonDockerCommand python scripts/parse_file_size.py ${inFile1}* >> $resultFile
  $pythonDockerCommand python scripts/parse_file_size.py ${inFile2}* >> $resultFile
  $pythonDockerCommand python scripts/parse_file_size.py ${outFile2}* >> $resultFile
  echo >> $resultFile
}

mkdir -p data/transposed data/transposed_and_compressed

tcResultFile=results/transposed_compressed.tsv

#echo -e "NumDiscrete\tNumNumeric\tNumRows\tMethod\tLevel\tUncompressedSize_kb\tPortraitCompressedSize_kb\tLandscapeCompressedSize_kb" > $tcResultFile

#for level in 1 5 9 22
#do
#    transposeAndCompressLines $tcResultFile $small zstd $level
#    transposeAndCompressLines $tcResultFile $tall zstd $level
#    transposeAndCompressLines $tcResultFile $wide zstd $level
#done

############################################################
# Measure how quickly we can query the files that have
# been compressed line-by-line. This time use the transposed
# version of the data for filtering.
############################################################

##for iteration in {1..5}
#for iteration in {1..1}
#do
#    for queryType in simple startsendswith
#    for queryType in simple
#    for queryType in startsendswith
#    do
#        for size in "$small" "$tall" "$wide"
#        for size in "$small"
#        for size in "$tall"
#        for size in "$wide"
#        do
#            for columns in firstlast_columns all_columns
#            for columns in firstlast_columns
#            for columns in all_columns
#            do
#                for level in 1 5 9 22
#                for level in 1
#                do
#                    queryFile $iteration $size FWF zstd__${level} Python "transposed" 1 "${pythonDockerCommand}" "python scripts/fwf2_cmpr_trps.py zstd ${level}" $queryType $columns False fwf2 "" $queryResultFile
#                    queryFile $iteration $size FWF zstd__${level} Rust "transposed" 1 "${rustDockerCommand}" "/Rust/fwf2_cmpr_trps/target/release/main zstd ${level}" $queryType $columns False fwf2 "" $queryResultFile
#                done
#            done
#        done
#    done
#done

############################################################
# Test additional features: indexes, binary search,
# concise format, parallelization, custom compression.
############################################################

buildResultFile=results/build_f4py.tsv
#echo -e "Iteration\tNumDiscrete\tNumNumeric\tNumRows\tThreads\tCompressionType\tIncludesEndsWithIndex\t\tWallClockSeconds\tUserSeconds\tSystemSeconds\tMaxMemoryUsed_kb\tOutputFileSize_kb" > $buildResultFile

#for iteration in {1..5}
#for iteration in {1..1}
#do
#    for size in "$small" "$tall" "$wide"
#    for size in "$small"
#    #for size in "$tall"
#    #for size in "$wide"
#    do
#        for threads in 1
#        for threads in 16
#        #for threads in 1 4 16
#        do
#            for compression_type in None
#            for compression_type in None zstd
#            do
#                dataFile=data/${size// /_}.tsv
#
#                outFile=data/${size// /_}_${compression_type}.f4
#                rm -rf ${outFile}*
#
#                echo -n -e "${iteration}\t${size// /\\t}\t${threads}\t${compression_type}\t" >> $buildResultFile
#                command="python scripts/convert_to_f4.py $dataFile $threads ${compression_type} Discrete2,Numeric2;Discrete2_endswith,Numeric2 $outFile"
#
#                echo $command
#                $pythonDockerCommand $command
#                $pythonDockerCommand /usr/bin/time --verbose $command &> /tmp/result
#                $pythonDockerCommand python scripts/parse_time_memory.py /tmp/result >> $buildResultFile
#                $pythonDockerCommand python scripts/parse_file_size.py ${outFile} >> $buildResultFile
#                echo >> $buildResultFile
#            done
#        done
#    done
#done

#for iteration in {1..5}
#for iteration in {1..3}
#for iteration in {1..1}
#do
#    for size in "$small" "$tall" "$wide"
#    for size in "$small"
#    #for size in "$tall"
#    #for size in "$wide"
#    do
#        for queryType in simple startsendswith
#        for queryType in simple
#        for queryType in startsendswith
#        do
#            for columns in firstlast_columns all_columns
#            for columns in firstlast_columns
#            for columns in all_columns
#            do
#                for threads in 1
#                for threads in 4
#                for threads in 16
#                for threads in 1 4
#                for threads in 1 4 16
#                do
#                    for compression_type in None
#                    for compression_type in zstd
#                    for compression_type in None zstd
#                    do
#                        queryFile $iteration $size F4 ${compression_type} Python "basic - f4" ${threads} "${pythonDockerCommand}" "python scripts/query_f4.py $threads ${compression_type}" $queryType $columns False f4 "_${compression_type}" $queryResultFile
#                    done
#                done
#            done
#        done
#    done
#done

exit

############################################################
# Real-world data: ARCHS4
############################################################

mkdir -p data/archs4

#TODO:
#  Parse tsv.gz files and combine them into one. Parse the characteristics and set defaults to NA.
#  Convert to f4 rather than fwf2.
#  Run queries. Probably don't need to validate the output. Just check metrics.

#$pythonDockerCommand wget -O data/archs4/human_tpm_v11.h5 https://s3.amazonaws.com/mssm-seq-matrix/human_tpm_v11.h5
#$pythonDockerCommand python convert_archs4_hdf5_to_tsv.py data/archs4/human_tpm_v11.h5 data/archs4/human_tpm_v11_sample.tsv.gz data/archs4/human_tpm_v11_expr.tsv.gz
#$pythonDockerCommand python parse_archs4.py data/archs4/human_tpm_v11_sample.tsv.gz data/archs4/human_tpm_v11_expr.tsv.gz data/archs4/archs4.f4
#rm -f data/archs4/archs4_sample.tsv.gz
#TODO: Write code to query In parse_archs4.py, remove temp files. They are in the data dir. Then change the paths so these are in data/archs4.

############################################################
# Real-world data: CADD
############################################################

mkdir -p data/cadd

#TODO: remove these two lines?
#$pythonDockerCommand wget -O data/cadd/whole_genome_SNVs.tsv.gz https://krishna.gs.washington.edu/download/CADD/v1.6/GRCh38/whole_genome_SNVs.tsv.gz
#$pythonDockerCommand wget -O data/cadd/whole_genome_SNVs.tsv.gz.tbi https://krishna.gs.washington.edu/download/CADD/v1.6/GRCh38/whole_genome_SNVs.tsv.gz.tbi
#$pythonDockerCommand wget -O data/cadd/whole_genome_SNVs_inclAnno.tsv.gz https://krishna.gs.washington.edu/download/CADD/v1.6/GRCh38/whole_genome_SNVs_inclAnno.tsv.gz
#$pythonDockerCommand wget -O data/cadd/whole_genome_SNVs_inclAnno.tsv.gz.tbi https://krishna.gs.washington.edu/download/CADD/v1.6/GRCh38/whole_genome_SNVs_inclAnno.tsv.gz.tbi

#$pythonDockerCommand zcat data/cadd/whole_genome_SNVs_inclAnno.tsv.gz | head -n 10000 | gzip > data/cadd/small.tsv.gz
$pythonDockerCommand python convert_cadd.py data/cadd/whole_genome_SNVs_inclAnno.tsv.gz data/cadd/cadd.f4
# The full-sized CADD file has 12221577961 lines total.



#$pythonDockerCommand python convert_cadd.py data/cadd/small.tsv.gz data/cadd/full.tsv.gz

#zcat data/whole_genome_SNVs_inclAnno.tsv.gz | head -n 2 | tail -n +2 | cut -c2- | gzip > data/cadd.tsv.gz
#zcat data/whole_genome_SNVs_inclAnno.tsv.gz | tail -n +3 | gzip >> data/cadd.tsv.gz


#zcat data/cadd.tsv.gz | head -n 1001 > /tmp/cadd_head_small.tsv
#zcat data/cadd.tsv.gz | head -n 10000001 > /tmp/cadd_head_medium.tsv

#sed -r 's/1\t([0-9])/X\t\1/g' /tmp/cadd_head_small.tsv > /tmp/cadd_head_small_X.tsv
#sed -r 's/1\t([0-9])/X\t\1/g' /tmp/cadd_head_medium.tsv > /tmp/cadd_head_medium_X.tsv

#tail -n +2 /tmp/cadd_head_small_X.tsv > /tmp/cadd_head_small_X2.tsv
#tail -n +2 /tmp/cadd_head_medium_X.tsv > /tmp/cadd_head_medium_X2.tsv

#cat /tmp/cadd_head_small.tsv /tmp/cadd_head_small_X2.tsv > data/cadd_head_small.tsv
#cat /tmp/cadd_head_medium.tsv /tmp/cadd_head_medium_X2.tsv > data/cadd_head_medium.tsv

#gzip data/cadd_head_small.tsv
#gzip data/cadd_head_medium.tsv

##$dockerCommand bash -c "python3 ConvertCADD.py 'data/cadd_head_small.tsv.gz' 'data/cadd_head_small' 32 5 100 Chrom,Pos,Consequence,ConsScore 1 False /tmp/cadd_small ''"
#$dockerCommand bash -c "python3 ConvertCADD.py 'data/cadd_head_small.tsv.gz' 'data/cadd_head_small' 1 5 100 Chrom,Pos,Consequence,ConsScore 1 True /tmp/cadd_small ''"
#$dockerCommand bash -c "python3 ConvertCADD.py 'data/cadd_head_small.tsv.gz' 'data/cadd_head_small' 32 5 100 Chrom,Pos,Consequence,ConsScore 1 True /tmp/cadd_small ''"
##$dockerCommand bash -c "python3 ConvertCADD.py 'data/cadd_head_medium.tsv.gz' 'data/cadd_head_medium' 32 5 100 Chrom,Pos,Consequence,ConsScore 1 False /tmp/cadd_medium ''"
#$dockerCommand bash -c "python3 ConvertCADD.py 'data/cadd_head_medium.tsv.gz' 'data/cadd_head_medium' 32 5 100 Chrom,Pos,Consequence,ConsScore 1 True /tmp/cadd_medium ''"
##$dockerCommand bash -c "python3 ConvertCADD.py 'data/cadd_head_medium.tsv.gz' 'data/cadd_head_medium' 32 5 100 Chrom,Pos,Consequence,ConsScore 11 True /tmp/cadd_medium ''"

#mkdir -p /tmp/cadd
#python3 ConvertCADD.py "data/cadd.tsv.gz" "data/cadd" 28 5 100000 Chrom,Pos,Consequence,ConsScore /tmp/cadd
# 19814003803 lines according to wc -l in data/cadd.f4

#python3 ConvertTsvToFixedWidthFile2.py data/cadd.tsv.gz data/cadd.fwf2
#python3 ConvertTsvToFixedWidthFile2.py data/cadd.tsv.gz /tmp/1.fwf2

#rm -f data/whole_genome_SNVs_inclAnno.tsv.gz data/whole_genome_SNVs_inclAnno.tsv.gz.tbi

#python3 F4/Builder.py data/cadd.tsv.gz data/cadd.f4 "\t" 30

# 12,221,577,960 rows in CADD file (excluding header).
# 134 columns


exit

#TODO: Real-world biology data
#        - ARCHS4 Version 2 (Ensembl 107), TPM (transcript level, human, 101 GB, 11-16-2021)
#          Show that we can transpose such a large file.
#        - CADD
#            Transposing doesn't really make sense for this one.
#            Compare against tabix? We can also compare it in terms of size.
#              tabix sorted.gff.gz chr1:10,000,000-20,000,000
#              Try CSI index files https://github.com/enasequence/schema/issues/18
#      Build a simple web-server container (fastAPI?) to demonstrate remote queries.
#        Peek
#        Filter/query
#TODO: Try two levels of compression with fst (and next fastest).
#      First, compress.
#      Second, query.
#TODO: Clean up scripts.
#TODO: Run everything from beginning to end (sensei? miyagi?).

#NOTES:
#  When parsing tall file (Python):
#    About half of the time is used when calling parse_data_coords().
#    About 35% of the time is used to decompress the relevant lines in the main file.
#    About 10% of the time is used to write the output file.
#  When parsing wide file (Python):
#    Nearly all of the time is used to decompress the relevant lines in the main file.

############################################################
# Build pseudo-genotype files. Measure how long it takes to
# build, query, and transpose these files (of increasing
# size).
############################################################

#TODO: Move this up before we do anything with compression?
function runGenotypeTests {
  resultFile=$1
  dimensions=$2

  dataFile=TestData/Genotypes_${dimensions}.fwf2
  rowIndicesFile=TestData/Genotypes_${dimensions}.ri
  colIndicesFile=TestData/Genotypes_${dimensions}.ci

  echo -e "Build\t$dimensions\t$( { /usr/bin/time -f %e python3 BuildGenotypes.py $dimensions $dataFile > /dev/null; } 2>&1 )" >> $resultFile
  #time python3 BuildGenotypes.py $dimensions $dataFile

  echo -e "Size\t$dimensions\t$(python3 PrintFileSize.py $dataFile)" >> $resultFile
  echo -e "ll Size\t$dimensions\t$(python3 PrintFileSize.py $dataFile.ll)" >> $resultFile
  echo -e "mccl Size\t$dimensions\t$(python3 PrintFileSize.py $dataFile.mccl)" >> $resultFile
  echo -e "cc Size\t$dimensions\t$(python3 PrintFileSize.py $dataFile.cc)" >> $resultFile

  # Build a file that indicates which column indices to query before performing the actual query.
  echo -e "Build Row Indices\t$dimensions\t$( { /usr/bin/time -f %e python3 BuildRandomIndicesFile.py $dimensions 1 $rowIndicesFile > /dev/null; } 2>&1 )" >> $resultFile
  echo -e "Build Column Indices\t$dimensions\t$( { /usr/bin/time -f %e python3 BuildRandomIndicesFile.py $dimensions 2 $colIndicesFile > /dev/null; } 2>&1 )" >> $resultFile

  echo -e "Query\t$dimensions\t$( { /usr/bin/time -f %e python3 TestFixedWidth5.py $dataFile $rowIndicesFile $colIndicesFile $dataFile.tmp > /dev/null; } 2>&1 )" >> $resultFile
  #time python3 TestFixedWidth5.py $dataFile $rowIndicesFile $colIndicesFile $dataFile.tmp

  /usr/bin/time -v python3 TransposeFixedWidthGenotypes.py $dataFile $dimensions $dataFile.tmp 2> TestData/TempResults/1
  #time python3 TransposeFixedWidthGenotypes.py $dataFile $dimensions $dataFile.tmp
  python3 ParseTimeOutput.py TestData/TempResults/1 $dimensions >> $resultFile

  echo -e "Transposed Size\t$dimensions\t$(python3 PrintFileSize.py $dataFile.tmp)" >> $resultFile

  rm -f $dataFile ${dataFile}* TestData/TempResults/1
}

resultFile=Results2/Results_Genotypes.tsv

#if [ ! -f $resultFile ]
#then
  echo -e "Description\tDimensions\tValue" > $resultFile

  runGenotypeTests $resultFile 10
#  runGenotypeTests $resultFile 50
#  runGenotypeTests $resultFile 100
#  runGenotypeTests $resultFile 500
#  runGenotypeTests $resultFile 1000
#  runGenotypeTests $resultFile 5000
#  runGenotypeTests $resultFile 10000
#  runGenotypeTests $resultFile 50000
#  runGenotypeTests $resultFile 100000
#  runGenotypeTests $resultFile 500000
#fi

############################################################
# Clean up the test files created so far to save disk space.
############################################################

#TODO:
#rm -rfv TestData/*
