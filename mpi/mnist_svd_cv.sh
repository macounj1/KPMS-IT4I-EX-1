#!/bin/bash
#PBS -N mnist_svd_cv
#PBS -l select=1:ncpus=128,walltime=00:50:00
#PBS -q qexp
#PBS -e mnist_svd_cv.e
#PBS -o mnist_svd_cv.o

cd ~/KPMS-IT4I-EX/mpi
pwd

module load R
echo "loaded R"

export OMPI_MCA_mpi_warn_on_fork=0
export RDMAV_FORK_SAFE=1


module swap libfabric/1.12.1-GCCcore-10.3.0 libfabric/1.13.2-GCCcore-11.2.0

## --args blas fork
time mpirun -np 2 Rscript mnist_svd_cv.R 
