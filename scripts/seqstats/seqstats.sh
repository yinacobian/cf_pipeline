#!/bin/bash
# seqstats.sh
# Sequence statistics pipeline
#
# Author: Daniel A Cuevas (dcuevas08.at.gmail.com)
# Created on 23 Nov 2016
# Updated on 20 Mar 2017

VERSION="0.1"

usage() {
    echo "$1
$scriptname version $VERSION

usage: $scriptname -f fastq -d output_dir [Options]

Required
   -f [fastq]              : FASTQ file
   -o [output_dir]         : Directory for output files

Optional
   --gc                    : Flag to calculate GC
   --gz                    : Flag for gzipped compressed files
   --fasta                 : Flag for FASTA file instead of FASTQ
   -t                      : Title for plots
   -v                      : Verbose output
   -h, -?, --help          : This help message

Notes
   - None

" >&2
}


error() {
    echo "*****FATAL ERROR OCCURRED*****" >&1 | tee -a $log
    echo $1 >&1 | tee -a $log
    exit 1
}


getTime() {
    currtime=$(date "+[%F %H:%M:%S]")
}


timeStamp() {
    timestamp=$(date "+%Y%m%dT%H%M%S")
}


####################################################
#ARGUMENT PARSING
####################################################
scriptdir=$(cd $(dirname $0); pwd -P)
scriptname=$(echo $0 | perl -ne '/\/?.*\/(.+)/; print $1;')
fastq=""
fastaflag=0
gzippedflag=0
gcflag=0
outdir=""
title=""
verbose=0

# Set pipefail for catching errors in piped commands
set -o pipefail

while [[ $# != 0 ]]; do
    case $1 in
    -h|-\?|--help)
        usage
        exit 2
        ;;
    -f)
        shift
        [[ ! $1 || $(printf "%s" "$1" | perl -ne 'm/(^-.$)/; print $1;') ]] && echo "Missing -f value" >&2 && usage && exit 2
        fastq=$1
        ;;
    -o)
        shift
        [[ ! $1 || $(printf "%s" "$1" | perl -ne 'm/(^-.$)/; print $1;') ]] && echo "Missing -o value" >&2 && usage && exit 2
        outdir=$1
        ;;
    -t)
        shift
        [[ ! $1 || $(printf "%s" "$1" | perl -ne 'm/(^-.$)/; print $1;') ]] && echo "Missing -t value" >&2 && usage && exit 2
        title=$1
        ;;
    --fasta)
        fastaflag=1
        ;;
    --gz)
        gzippedflag=1
        ;;
    --gc)
        gcflag=1
        ;;
    -v)
        verbose=1
        ;;
    *)
        echo "Unknown option $1" >&2
        usage
        exit 2
    esac
    shift
done

# Check if required variables are set
if [[ ! $fastq || ! $outdir ]]; then
    usage "Missing one or more required arguments."
    exit 2
fi

# Extract name from FASTQ file
name=$(basename $fastq)
name=${name%.*}

gzip=""
# Check if files are gzipped
if (( $gzippedflag )); then
    gzip="--gzip"
    # File name had two suffixes, must remove one more
    name=${name%.*}
fi

# Check if title was given
if [[ ! $title ]]; then
    title=$name
fi

fasta=""
# Check if files are fasta
if (( $fastaflag )); then
    fasta="--fasta"
fi

vflag=""
if (( $verbose )); then
    vflag="-v"
fi

gc=""
# Check if GC is to be calculated
if (( $gcflag )); then
    gc="--gc"
fi

# Begin statistics scripts
getTime && echo "${currtime}    *****Starting sequence statistics scripts*****"  >&1
(( !$verbose )) && getTime && echo "${currtime}    Note: verbose flag was not set."  >&1
(( $fastaflag )) && getTime && echo "${currtime}    Note: FASTA flag was set -- no quality output will be produced"  >&1
(( !$gcflag )) && getTime && echo "${currtime}    Note: GC flag was not set -- no GC output will be produced"  >&1

# Calculate sequencing stats
cmd="python3 ${scriptdir}/calcSeqStats.py $fastq $outdir --header $fasta $gzip $gc $vflag"
(( $verbose )) && getTime && echo "${currtime}    Executing $cmd"  >&1
eval $cmd  2>&1
[[ $? -ne 0 ]] && getTime && error "${currtime}    Fail on command: $cmd"

# Plot quality stats
if (( $fastaflag )); then
    (( $verbose )) && getTime && echo "${currtime}    Skipping quality plots"  >&1
else
    cmd="Rscript ${scriptdir}/seqstats_density.R -i ${outdir}/${name}_qualities.tsv -d $outdir --header -s qualities -t $title"
    (( $verbose )) && getTime && echo "${currtime}    Executing $cmd"  >&1
    eval $cmd  2>&1
    [[ $? -ne 0 ]] && getTime && error "${currtime}    Fail on command: $cmd"
fi

# Plot GC ratio stats
if (( $gcflag )); then
    cmd="Rscript ${scriptdir}/seqstats_density.R -i ${outdir}/${name}_gcratios.tsv -d $outdir --header -s gcratios -t $title"
    (( $verbose )) && getTime && echo "${currtime}    Executing $cmd"  >&1
    eval $cmd  2>&1
    [[ $? -ne 0 ]] && getTime && error "${currtime}    Fail on command: $cmd"
fi

# Plot sequence length stats
############################
## SKIPPING ##
#cmd="Rscript seqstats_readLengths.R -i ${outdir}/${name}_readlengths -d $outdir --header -t $title"
#(( $verbose )) && getTime && echo "${currtime}    Executing $cmd"  >&1
#eval $cmd  2>&1
#[[ $? -ne 0 ]] && getTime && error "${currtime}    Fail on command: $cmd"

getTime && echo "${currtime}    *****Completed!*****"  >&1
