#!/bin/bash

# Set regex constants.
REGEX_HELP="(^--help$)|(^-[^-]*h[^-]*$)"
REGEX_VERBOSE="(^--verbose$)|(^-[^-]*v[^-]*$)"
REGEX_FORCE="(^--force$)|(^-[^-]*f[^-]*$)"
REGEX_CLEAN="(^--clean$)|(^-[^-]*c[^-]*$)"
REGEX_NO_BAC="(^--no-backup$)|(^-[^-]*b[^-]*$)"
REGEX_OUTPUT="(^--output$)|(^-[^-]*o[^-]*$)"
REGEX_CACHE="(^--no-cache$)|(^-[^-]*C[^-]*$)"

VERBOSE=0
FORCE=0
CLEAN=0
NO_BAC=0
OUT_FILE=""
CACHE=0

# Interpret options.
prevOut=0
first=0
for arg in "$@"; do
    found=0
    if [ $prevOut = 1 ]; then
        echo "HERE"
        OUT_FILE=$arg
        prevOut=0
        continue
    fi
    if [[ $arg =~ ${REGEX_HELP} ]]; then
        echo "USAGE
    ./gen.sh SOURCE [OPTIONS]
SOURCE
    The file source file to process.
OPTIONS
    -h, --help              Display this help and exit.
    -v, --verbose           Adds more debug logging of the process.
    -f, --force             Doesn't ask the user to anything and overwrites any files if they already exist.
    -c, --clean             Delete files in the generation folder when done.
    -n, --no-backup         Generate no backup files.
    -o <OUT> --output <OUT> Outputs the data to the given <OUT> file. The default is 'path/to/source/sname.aut'.
    -C, --no-cache          Don't use caching to generate the result.
"
        exit
    fi
    # Ignore the first argument.
    if [ $first = 0 ]; then
        first=1
        continue
    fi
        
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
        CACHE_OPT="--cached"
    fi
    
    # Filter out unknown options.
    if [ $found = 0 ]; then
        echo "[ERROR] Unknown option: "$arg
        exit
    fi
done
if [ $prevOut = 1 ]; then
    echo "[ERROR] Expected an argument after '-o' or '--output'. Use '-h' or '--help' for more info."
    exit
fi


# DEBUG
#echo "[INFO ] verbose  = "$VERBOSE
#echo "[INFO ] force    = "$FORCE
#echo "[INFO ] clean    = "$CLEAN
#echo "[INFO ] no-back  = "$NO_BAC
#echo "[INFO ] output   = "$OUT_FILE
#echo "[INFO ] no-cache = "$CACHE


# Set file constants and check if the source exists.
SOURCE=$1
if [ ! -f $SOURCE ]; then
    echo "[ERROR] Source file does not exist!"
    exit
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


# Backup/delete old files.
for file in "$LPS_FILE" "$LTS_FILE" "$AUT_FILE" "$OPT_FILE" "$OUT_FILE"; do
    if [ $NO_BAC = 0 ]; then
        if [ -f "$file" ]; then
            if [ $FORCE = 0 ] && [ -f "$file.bac" ]; then
                echo "$file.bac"
                echo -n "The backup file '$file.bac' will be deleted. Do you want to continue? (Y/n) "
                read ans
                if [[ "$ans" = "n" ]]; then
                    echo "[INFO ] User aborted program."
                    exit
                fi
            fi
            [ $VERBOSE = 1 ] && echo -n "[INFO ] "
            mv -f $VERB_OPT "$file" "$file.bac"
        fi
        
    else
        if [ -f "$file" ]; then
            if [ $FORCE = 0 ]; then
                echo -n "The file '$file' will be deleted. Do you want to continue? (Y/n) "
                read ans
                if [[ "$ans" = "n" ]]; then
                    echo "[INFO ] User aborted program."
                    exit
                fi
            fi
            [ $VERBOSE = 1 ] && echo -n "[INFO ] "
            rm -f $VERB_OPT "$file"
        fi
    fi
done

mcrl22lps $VERB_OPT $CACHE_OPT "$SOURCE" "$LPS_FILE"
lps2lts $VERB_OPT $CACHE_OPT "$LPS_FILE" "$OUT_FILE" #"$LTS_FILE"
#TODO: optimize
#ltsconvert $VERB_OPT --equivalence=branching-bisim --in=lts --out=aut "$LTS_FILE" "$OUT_FILE"

if [ $CLEAN = 1 ]; then
    for file in "$LPS_FILE" "$LTS_FILE" "$AUT_FILE" "$OPT_FILE"; do
        [ -f "$file" ] && rm $VERB_OPT "$file"
    done
fi

