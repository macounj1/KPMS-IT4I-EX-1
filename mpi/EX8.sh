#!/bin/bash
#PBS -N mnist_svd_mv
#PBS -l select=2:ncpus=128,walltime=00:50:00
#PBS -q qexp
#PBS -e mnist_svd_mv.e
#PBS -o mnist_svd_mv.o

cd ~/KPMS-IT4I-EX/mnist
pwd

module load R
echo "loaded R"

time Rscript mnist_svd_mv.R

time mpirun --map-by ppr:64:node Rscript rf_mpi.R



