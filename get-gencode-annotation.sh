#!/usr/bin/env bash

# This script downloads gff3 files from gencode and generates annotation files 

PROGRAM="get-gencode-annotation.sh"
VERSION="1.0"

# If we don't have enough arguments, print the help
if [ $# -lt "3" ]; then
	echo "${IFS}$PROGRAM $VERSION - This script downloads gff3 files from gencode and generates annotation files $IFS"

echo "Use: $PROGRAM [SPECIE] [GENOME_VERSION] [GENCODE_VERSION] [DOWNLOAD_GTF] [GENERATE_BED_FILES] [DOWNLOAD_TRANSCRIPT]$IFS"
echo "1	[ SPECIE ] - human or mouse (in lower case)"
echo "2	[ GENOME_VERSION ] - genome version. E.g. hg38 or mm39. It will be put at the begining of all files"
echo "3	[ GENCODE_VERSION ] - gencode version you want to download. E.g. 47 for human or M35 for mouse. Make sure it matches genome version"
echo "4	[ DOWNLOAD_GTF ] - NO if you do not want to download the file from gencode. It will expect to find a file named GENOME_VERSION-gencode-GENCODE_VERSION.gff3. Default: YES"
echo "5	[ GENERATE_BED_FILES ] - NO if you do not want to generate bed files. Default: YES"
echo "6	[ DOWNLOAD_TRANSCRIPT ] - NO if you do not want to download the transctipt file from gencode. Default: YES"
echo ""
echo "The script asumes you have the following tools/scripts available:"
echo "bedtools"
echo "BedFlank.pl"
echo "gff3ToBed.pl"
echo ""
echo "It also requires a GENOME_VERSION.len file with the format <chr_name><tab><chr_length>"
echo ""
exit 2
fi

#Asign variables
SP=$1
G=$2
V=$3

GTF=$4
GTF=${GTF:="YES"}

BED=$5
BED=${BED:="YES"}

TRANS=$6
TRANS=${TRANS:="YES"}

GENCODE_FTP="https://ftp.ebi.ac.uk/pub/databases/gencode"

### Check files

# Check .len and .names files
if [ ! -f $G.len ]; then
	echo "ERROR: the $G.len file is not present. You need a $G.len file with the format <chr name><tab><length>." >&2; exit 1 # If the .len file is not there print to STDERR and exit
fi

if [ ! -f $G.names ]; then
	cut -f 1 $G.len > $G.names #If the .names file does not exist, create it
fi


### Download GFT

if [ $GTF != "NO" ]; then
	# Download GFF3 annotation from gencode:
	echo "Downloading gencode.v$V.annotation.gff3.gz from $GENCODE_FTP/Gencode_$SP/release_$V/"
	curl -o temp-$V.gtf.gz $GENCODE_FTP/Gencode_$SP/release_$V/gencode.v$V.annotation.gff3.gz

	gzip -dc temp-$V.gtf.gz | head > temp-$V-test
	if [ ! -s temp-$V-test ]; then
		echo "ERROR: the file file gencode.v$V.annotation.gff3.gz is empty. Make sure it exists in the release_$V folder at $GENCODE_FTP/Gencode_$SP/" >&2; rm temp-${V}*; exit 1 # If the file is not there print to STDERR and exit
	fi

	# Eliminate version number from gene/transcripts IDs:
	gzip -dc temp-$V.gtf.gz | sed 's/\.[0-9]//g' | gzip -c > $G-gencode-$V.gff3.gz
	rm temp-$V.gtf.gz

	echo "Finished download. Gff3 file is saved as $G-gencode-$V.gff3.gz"
fi

# Check gff3 file and exit if it is not present:
if [ ! -s $G-gencode-$V.gff3.gz ]; then
	echo "ERROR: the file file $G-gencode-$V.gff3.gz is not present. Make sure it exists and try again" >&2; exit 1 # If the file is not there print to STDERR and exit
fi


### Generate BED files

if [ $BED != "NO" ]; then
	# Generating sub-gff3 files from different genomic regions
	echo "Generating bed files..."
	
	gzip -dc $G-gencode-$V.gff3.gz > temp-$V.gff3
#	gzip -dc $G-gencode-$V.gff3.gz | awk '{if($3=="gene"){print $0}}' > temp-$V-gene.gff3
#	gzip -dc $G-gencode-$V.gff3.gz | awk '{if($3=="exon"){print $0}}' > temp-$V-exon.gff3
#	gzip -dc $G-gencode-$V.gff3.gz | awk '{if($3=="five_prime_UTR"){print $0}}' > temp-$V-5UTR.gff3
#	gzip -dc $G-gencode-$V.gff3.gz | awk '{if($3=="three_prime_UTR"){print $0}}' > temp-$V-3UTR.gff3
#	gzip -dc $G-gencode-$V.gff3.gz | awk '{if($3=="transcript"){print $0}}' > temp-$V-tx.gff3

	# Getting gene bed file 
	gff3ToBed.pl -f temp-$V.gff3 -t gene | sortBed -i - -faidx $G.names | uniq > $G-gencode-$V-all.bed

	# Generating gene bed without pseudogenes 
	grep -v "pseudogene" $G-gencode-$V-all.bed > $G-gencode-$V-gene.bed

	# Generating bed for coding and non-coding genes:
	grep "protein_coding" $G-gencode-$V-gene.bed > $G-gencode-$V-gene-coding.bed
	grep -v "protein_coding" $G-gencode-$V-gene.bed > $G-gencode-$V-gene-noncoding.bed

	# Generating bed promoter file (-1kb to -1)
	BedFlank.pl -f $G-gencode-$V-gene.bed -up 1001 -down -1 -5 -g $G.len --silent | sortBed -i - -faidx $G.names > $G-gencode-$V-promoter_1kb.bed

	# Generating bed for intergenic regions: 
	BedFlank.pl -f $G-gencode-$V-all.bed -up 1001 -g $G.len -silent | sortBed -i - -faidx $G.names > temp-$V-intergenic
	complementBed -i temp-$V-intergenic -g $G.len | awk '{print $1"\t"$2"\t"$3"\t.\t.\t+" }' > $G-gencode-$V-intergenic.bed

	# Generating exon and UTR bed files:

	for F in exon five_prime_UTR three_prime_UTR
	do
		gff3ToBed.pl -f temp-$V.gff3 -t $F | sortBed -i - -faidx $G.names | uniq | mergeBed -i - -s -c 4,5,6,7 -o distinct,distinct,distinct,distinct -delim "," | sortBed -i - -faidx $G.names > $G-gencode-$V-$F.bed
	done
	
	# Get list of gene_id and gene_name
	cut -f 4,5 $G-gencode-$V-all.bed | sort -k2 > $G-gencode-$V-gene_id-gene_name.txt
	
	# Get list of gene_id and gene_type
	cut -f 4,7 $G-gencode-$V-all.bed | sort | uniq > $G-gencode-$V-gene_id-gene_type.txt
	
	# Get list of gene_id and  transcript_id
	gff3ToBed.pl -f temp-$V.gff3 -t transcript -c5 transcript_id | cut -f 4,5 | sort -k1 > $G-gencode-$V-gene_id-transcript_id.txt
	
	rm temp-${V}*
	echo "All bed files have been generated."
fi

### Download transcript file

if [ $TRANS != "NO" ]; then
	echo "Downloading transcript file gencode.v$V.transcripts.fa.gz from $GENCODE_FTP/Gencode_$SP/release_$V/"
	curl -o temp-$V-transcript.fa.gz $GENCODE_FTP/Gencode_$SP/release_$V/gencode.v$V.transcripts.fa.gz
	gzip -dc temp-$V-transcript.fa.gz | head > temp-$V-test
	if [ ! -s temp-$V-test ]; then
		echo "ERROR: the file gencode.v$V.transcripts.fa.gz is empty. Make sure it exists in the release_$V folder at $GENCODE_FTP/Gencode_$SP/" >&2; rm temp-${V}*;  exit 1 # If the file is not there print to STDERR and exit
	fi

	# Eliminate version number from gene/transcripts IDs:
	gzip -dc temp-$V-transcript.fa.gz | sed 's/\.[0-9]//g' | gzip -c > $G-gencode-$V-transcript.fa.gz
	rm temp-${V}*
	echo "Finished download. Fasta file is saved as $G-gencode-$V-transcript.fa.gz"
fi

echo ""
echo "ALL DONE!"
echo ""