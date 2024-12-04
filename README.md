# Gencode annotation
`get-gencode-annotation.sh` is a script that downloads a specified gencode annotation in gff3 format and generates several useful bed files. We use it to generate the annotation files we use in our bioinformatic projects.

---

## Description

The script is run through the terminal in an UNIX based system (Linux, Mac, etc.), so some (very) basic command line knowledge may be required to use it.

If you have questions, problems or suggestions, contact David Valle-Garcia (david dot valle dot edu -at- gmail dot com)

`get-gencode-annotation.sh` will perform 3 steps: 

### Step 1: Download GFF3 files

It will connect to Gencode's FTP site and download the indicated gff3 gene annotation. 

Gencode includes a version on its ids that is, for most purposes, not very useful. The script will eliminate it. 

So, if an id was for example ENSG00000290825.1, the script will change it to ENSG00000290825. This allows for some comparisons between different gene annotation versions.

### Step 2: Generate bed files

From the downloaded GFF3 file, the script will generate the following bed files:

* all genes
* genes without pseudogenes
* coding genes
* noncoding genes
* exons
* 5' UTRs
* 3' UTRs
* introns
* promoters (-1kb from TSS, excluding pseudogenes)
* intergenic regions

It will also generate tab-separated lists with:
* gene_id gene_name
* gene_id transcript_id
* gene_id gene_type

### Step 3: Download transcript sequences

It will connect to Gencode's FTP site and download the transcript fasta sequence that later may be used to generate indexes for salmon or kallisto. 

As with the GFF3, it will delete the id's version.

---

## Requirements:

### Software
* bedtools

From our [useful_scripts](https://github.com/david-valle/useful_scripts):
* BedFlank.pl
* gff3ToBed.pl

#### Compatible OS*:
* Ubuntu 24.04.1 LTS
* MacOS 14.6

\* The script should run in any UNIX based OS, but testing is required.

---

## Installation

Simply download the script from Github and run it. Type in a terminal: 
```
git clone https://github.com/david-valle/gencode_annotation
```
Go to the folder you just downloaded:
```
cd gencode_annotation
```
Run the script:
```
bash get-gencode-annotation.sh
```
A help message should appear.

---

## Usage

There are 3 required arguments for the script to run: Specie (mouse or human), genome version and gencode annotation version.

So, to download the human annotation from version 47, just type:
```
bash get-gencode-annotation.sh human hg38 47
```
This asumes that you have a .len file with chromosomes lengths in the folder where you are running the script (we provide .len files for human hg38 and mouse mm39 genomes in which the latest gencode annotations are based).

Note: if you add the script to your PATH, just type the script's name, without the 'bash' part.

Additionally, you can indicate whether you want to perform any of the three steps (see description for details) by writing YES or NO in sequential order. So, if you only want to download the GFF3 file and get the bed files (steps 1 and 2) but you don't want to download the transcript sequences, type:
```
bash get-gencode-annotation.sh human hg38 47 YES YES NO
```
If you just want to download the transcript fasta files (step 3):
```
bash get-gencode-annotation.sh human hg38 47 NO NO YES
```
If you just want to download the GFF3 file (step 1):
```
bash get-gencode-annotation.sh human hg38 47 YES NO NO
```
And so on.