#!/bin/bash
#PBS -N EX4
#PBS -l select=1:ncpus=128,walltime=00:50:00
#PBS -q qexp
#PBS -e EX4.e
#PBS -o EX4.o

cd ~/KPMS-IT4I-EX/code
pwd

module load R
echo "loaded R"

time Rscript EX4.R --args 64 8
