import difflib
import sys

outputFilePath = sys.argv[1]
expectedOutputFilePath = sys.argv[2]
errorResultFilePath = sys.argv[3]

def formatNumber(num):
    if "." in num or "e-" in num:
        return "{:.8f}".format(float(num))

    return num

def readFile(filePath):
    lines = []

    with open(filePath) as theFile:
        header_line = theFile.readline().rstrip("\n").split("\t")
        lines.append(header_line)

        for line in theFile:
            lines.append([formatNumber(x) for x in line.rstrip("\n").split("\t")])

    lines.sort()

    return lines

def saveErrorResult():
    with open(errorResultFilePath, "w") as errorFile:
        errorFile.write("Non-matching output")

actual_lines = readFile(outputFilePath)
expected_lines = readFile(expectedOutputFilePath)

if len(actual_lines) == 0:
    print(f"  FAIL: {outputFilePath} was empty.")

    saveErrorResult()
    sys.exit(1)

if len(expected_lines) == 0:
    print(f"  FAIL: {expectedOutputFilePath} was empty.")

    saveErrorResult()
    sys.exit(1)

if len(actual_lines) != len(expected_lines):
    print(f"  FAIL: {outputFilePath} and {expectedOutputFilePath} do not have the same number of lines.")

    saveErrorResult()
    sys.exit(1)

#actual_lines.sort()
#expected_lines.sort()

for line_count in range(1, len(actual_lines) + 1):
    line = actual_lines[line_count-1]
    expected_line = expected_lines[line_count-1]

    if line != expected_line:
        print(f"  FAIL: {outputFilePath} and {expectedOutputFilePath} are not equal.")
        print(f"    Line {line_count} of {outputFilePath}: {line}")
        print(f"    Line {line_count} of {expectedOutputFilePath}: {expected_line}")

        saveErrorResult()
        sys.exit(1)

print("  PASS")
