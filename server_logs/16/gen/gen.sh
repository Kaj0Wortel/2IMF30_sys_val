#!/bin/bash

RESULT_FILE="results/"$(date --iso-860=seconds)".log"

# Set regex constants.
REGEX_HELP="(^--help$)|(^-[^-]*h[^-]*$)"

REGEX_VERBOSE="(^--verbose$)|(^-[^-]*v[^-]*$)"
REGEX_FORCE="(^--force$)|(^-[^-]*f[^-]*$)"
REGEX_CLEAN="(^--clean$)|(^-[^-]*c[^-]*$)"
REGEX_NO_BAC="(^--no-backup$)|(^-[^-]*b[^-]*$)"
REGEX_OUTPUT="(^--output$)|(^-[^-]*o[^-]*$)"
REGEX_CACHE="(^--no-cache$)|(^-[^-]*C[^-]*$)"

REGEX_LTS_OPT="(^--lts$)|(^-[^-]*L[^-]*$)"
REGEX_VERIFY_OPT="(^--verify$)|(^-[^-]*V[^-]*$)"
REGEX_INPUT="(^--input$)|(^-[^-]*i[^-]*$)"
REGEX_CORES="(^--num-cores$)|(^-[^-]*N[^-]*$)"

VERBOSE=0
FORCE=0
CLEAN=0
NO_BAC=0
OUT_FILE=""
CACHE=0

LTS_OPT=0
VERIFY_OPT=0
NUM_CORES=1
VERIFY_INPUT=""
VERIFY_INPUT_LENGTH=0
CACHE_OPT="--cached"

# Interpret options.
prevOut=0
prevIn=0;
prevCores=0;
first=0
for arg in "$@"; do
    found=0
    if [[ $prevOut == 1 ]]; then
        OUT_FILE="${$arg}"
        prevOut=0
        continue
    fi
    if [[ ${prevIn} == 1 ]]; then
        VERIFY_INPUT[$VERIFY_INPUT_LENGTH]="${arg}"
        ((VERIFY_INPUT_LENGTH++))
        continue
    fi
    if [ $prevCores == 1 ]; then
        NUM_CORES=$arg
        prevCores=0
        continue
    fi
    if [[ $arg =~ ${REGEX_HELP} ]]; then
        echo "USAGE
    ./gen.sh SOURCE [OPTIONS] TYPE [TYPE OPTIONS]
SOURCE
    The file source file to process.
OPTIONS
    -h, --help              Display this help and exit.
    -v, --verbose           Adds more debug logging of the process.
    -f, --force             Doesn't ask the user to anything and overwrites any files if they already exist.
    -c, --clean             Delete files in the generation folder when done.
    -n, --no-backup         Generate no backup files.
    -o <OUT>, --output <OUT>
                            Outputs the data to the given 'OUT' file. The default is 'path/to/source/sname.aut'.
    -C, --no-cache          Don't use caching to generate the result.
TYPE
    -L, --lts               Generates an lts from the model.
    TYPE OPTIONS
        none
    -V, --verify            Verifies the model with the input property files.
    TYPE OPTIONS
        -i <IN...>, --input <IN...>
                            Required type option. Denotes the input property files. 'IN' denotes a
                            single input file. The input file is assumed to be '<INPUT>/../properties/<IN>[.mcf]'.
                            This options must be the last option. All other arguments after this option are
                            assumed to be files.
        -N <NUM>, --num-cores <NUM>
                            The number of cores used for verification. NUM denotes the number of cores.
"
        exit 0
    fi
    # Ignore the source argument.
    if [ $first = 0 ]; then
        first=1
        continue
    fi
    
    if [[ $LTS_OPT == 0 && $VERIFY_OPT == 0 ]]; then
        if [[ $arg =~ ${REGEX_VERBOSE} ]]; then
            found=1
            VERBOSE=1
            VERB_OPT="--verbose"
        fi
        if [[ $arg =~ ${REGEX_FORCE} ]]; then
            found=1
            FORCE=1
        fi
        if [[ $arg =~ ${REGEX_CLEAN} ]]; then
            found=1
            CLEAN=1;
        fi
        if [[ $arg =~ ${REGEX_NO_BAC} ]]; then
            found=1
            NO_BAC=1
        fi
        if [[ $arg =~ ${REGEX_OUTPUT} ]]; then
            found=1
            prevOut=1
        fi
        if [[ $arg =~ ${REGEX_CACHE} ]]; then
            found=1
            CACHE=1
            CACHE_OPT=""
        fi
        if [[ $arg =~ ${REGEX_LTS_OPT} ]]; then
            found=1
            LTS_OPT=1
        fi
        if [[ $arg =~ ${REGEX_VERIFY_OPT} ]]; then
            found=1
            VERIFY_OPT=1
        fi
        
        # Filter out unknown options.
        if [ $found = 0 ]; then
            echo "[ ERROR  ] Unknown option: "$arg
            exit 1
        fi
        
    elif [ $LTS_OPT == 1 ]; then
        :
        
    elif [ $VERIFY_OPT == 1 ]; then
        if [[ $arg =~ ${REGEX_INPUT} ]]; then
            found=1
            prevIn=1
        fi
        if [[ $arg =~ ${REGEX_CORES} ]]; then
            found=1
            prevCores=1
        fi
    fi
done

helpSentence="Use '-h' or '--help' for more info."
if [[ $1 -eq "" ]]; then
    echo "[ ERROR  ] 'SOURCE' option not found. "$helpSentence
    exit 1
fi
if [ $prevOut == 1 ]; then
    echo "[ ERROR  ] Expected an argument after '-o' or '--output'. "$helpSentence
    exit 1
fi
if [[ $LTS_OPT == 0 && $VERIFY_OPT == 0 ]]; then
    echo "[ ERROR  ] 'TYPE' option not found. "$helpSentence
    exit 1
fi
if [[ $VERIFY_OPT == 1 && $VERIFY_INPUT_LENGTH == 0 ]]; then
    echo "[ ERROR  ] '-i' or '--input' option not found in 'TYPE OPTIONS'. "$helpSentence
    exit 1
fi

# DEBUG
#echo "[  INFO  ] verbose  = "$VERBOSE
#echo "[  INFO  ] force    = "$FORCE
#echo "[  INFO  ] clean    = "$CLEAN
#echo "[  INFO   ] no-back  = "$NO_BAC
#echo "[  INFO  ] output   = "$OUT_FILE
#echo "[  INFO  ] no-cache = "$CACHE


# Set file constants and check if the source exists.
SOURCE=$1
if [ ! -f $SOURCE ]; then
    echo "[ ERROR  ] Source file does not exist!"
    exit 1
fi
ROOT="$(dirname "$1")"
NAME="$(basename "$1" .mcrl2)"
if [[ $OUT_FILE = "" ]]; then
    OUT_FILE=$ROOT"/"$NAME".aut"
fi
LPS_FILE=$ROOT"/gen/"$NAME".lps"
LTS_FILE=$ROOT"/gen/"$NAME".lts"
AUT_FILE=$ROOT"/gen/"$NAME".aut"
OPT_FILE=$ROOT"/gen/"$NAME"_opt.aut"
PBES_PREFIX=$ROOT"/gen/"$NAME"_"
BES_PREFIX=$ROOT"/gen/"$NAME"_"

# Backup/delete old files.
for file in "$LPS_FILE" "$LTS_FILE" "$AUT_FILE" "$OPT_FILE" "$OUT_FILE"; do
    if [ $NO_BAC = 0 ]; then
        if [ -f "$file" ]; then
            if [ $FORCE = 0 ] && [ -f "$file.bac" ]; then
                echo "$file.bac"
                echo -n "The backup file '$file.bac' will be deleted. Do you want to continue? (Y/n) "
                read ans
                if [[ "$ans" = "n" ]]; then
                    echo "[  INFO  ] User aborted program."
                    exit 0
                fi
            fi
            [ $VERBOSE = 1 ] && echo -n "[  INFO  ] "
            mv -f $VERB_OPT "$file" "$file.bac"
        fi
        
    else
        if [ -f "$file" ]; then
            if [ $FORCE = 0 ]; then
                echo -n "The file '$file' will be deleted. Do you want to continue? (Y/n) "
                read ans
                if [[ "$ans" = "n" ]]; then
                    echo "[  INFO  ] User aborted program."
                    exit 0
                fi
            fi
            [ $VERBOSE = 1 ] && echo -n "[  INFO  ] "
            rm -f $VERB_OPT "$file"
        fi
    fi
done


function verifyFile {
    local name="$1"
    propertyFile=$(dirname "${SOURCE}")"/properties/$name"
    if [[ $propertyFile =~ [^\.mcf]$ ]]; then
        propertyFile="$propertyFile.mcf"
    fi
    if [ ! -f "$propertyFile" ]; then
        echo "[ ERROR  ] The property file '$propertyFile' doesn't exist!"
        exit 1
    fi
    pbesFile="$PBES_PREFIX""$name"".pbes"
    besFile="$BES_PREFIX""$name"".bes"
    
    (($VERBOSE)) && echo "
[  INFO  ] GENERATING: LPS -> PBES FOR PROPERTY '$name'"
    lps2pbes $VERB_OPT --timings --out='pbes' --counter-example --preprocess-modal-operators --structured --formula="$propertyFile" "$LPS_FILE" "$pbesFile"
    if [[ $? -eq 1 ]]; then
        echo "[ ERROR  ] Could not generate PBES from LTS file!"
        exit 1
    fi
    if [[ 0 == 1 ]]; then
    (($VERBOSE)) && echo "
[  INFO  ] GENERATING: PBES -> BES FOR PROPERTY '$name'"
    pbes2bes $VERB_OPT --timings --erase='all' --in="pbes" --out="bes" --rewriter="jittyp" --strategy='3' "$pbesFile" "$besFile"
    
    (($VERBOSE)) && echo "
[  INFO  ] SOLVING: PBES FOR PROPERTY '$name'"
    echo "[  INFO  ] Started  solving property '$name' @ "$(date --rfc-3339=seconds) >> $RESULT_FILE
    bessolve $VERB_OPT --timings --in='bes' --strategy='lf' "$besFile" 2>&1 |
            while read line; do
                echo $line
                if [[ $line =~ false ]]; then
                    echo "[ FAILED ] The property '$name' is invalid!" >> $RESULT_FILE;
                    
                elif [[ $line =~ true ]]; then
                    echo "[   OK   ] The property '$name' is valid!" >> $RESULT_FILE;
                    
                else
                    continue;
                fi
                echo "[  INFO  ] Finished solving property '$name' @ "$(date --rfc-3339=seconds) >> $RESULT_FILE
            done
    else
    (($VERBOSE)) && echo "
[  INFO  ] SOLVING: PBES FOR PROPERTY '$name'"
    pbessolve $VERB_OPT --timings --in="pbes"  --rewriter="jittyp" --strategy='1' "$pbesFile" 2>&1 |
            while read line; do
                echo $line
                if [[ $line =~ false ]]; then
                    echo "[ FAILED ] The property '$name' is invalid!" >> $RESULT_FILE;
                    
                elif [[ $line =~ true ]]; then
                    echo "[   OK   ] The property '$name' is valid!" >> $RESULT_FILE;
                    
                else
                    continue;
                fi
                echo "[  INFO  ] Finished solving property '$name' @ "$(date --rfc-3339=seconds) >> $RESULT_FILE
            done
    fi
}


if [[ $LTS_OPT == 1 ]]; then
    mcrl22lps $VERB_OPT $CACHE_OPT "$SOURCE" "$LPS_FILE"
    lps2lts $VERB_OPT $CACHE_OPT "$LPS_FILE" "$OUT_FILE"
    #TODO: optimize
    #ltsconvert $VERB_OPT --equivalence=branching-bisim --in=lts --out=aut "$LTS_FILE" "$OUT_FILE"
    
elif [[ $VERIFY_OPT == 1 ]]; then
    (($VERBOSE)) && echo "
[  INFO  ] GENERATING: mCRL2 -> LPS"
    mcrl22lps --timings $VERB_OPT -- cluster "$SOURCE" "$LPS_FILE"
    if [[ $? -eq 1 ]]; then
        echo "[ ERROR  ] Could not generate LPS from mCRL2 file!"
        exit 1
    fi
    
    if [[ 0 == 1 ]]; then
    (($VERBOSE)) && echo "
[  INFO  ] GENERATING: LPS -> LTS"
    lps2lts --timings $VERB_OPT $CACHE_OPT "$LPS_FILE" "$LTS_FILE"
    if [[ $? -eq 1 ]]; then
        echo "[ ERROR  ] Could not generate LTS from LPS file!"
        exit 1
    fi
    fi
    
    i=0
    while [[ $i < $VERIFY_INPUT_LENGTH ]]; do
        sleep 0.5
        while
            amt="$(jobs -r | grep ^\[[0-9]*\].*$ -c)"
            #echo "amt: "$amt
            #echo $(jobs)
            #echo $NUM_CORES
            (( $amt >= $NUM_CORES ))
        do
            sleep 1
        done
        echo "NAME: ""${VERIFY_INPUT[$i]}"
        verifyFile "${VERIFY_INPUT[$i]}" &
        ((i++))
    done
    wait
fi

if [ $CLEAN = 1 ]; then
    for file in $ROOT/gen/$NAME*; do
        if [[ ! file =~ ^.*evidence.lts$ && -f $file ]]; then
            rm -f $VERB_OPT "$file"
        fi
    done
fi
