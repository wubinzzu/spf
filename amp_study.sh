#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "usage: ./study [data-dir] [output-dir]"
    exit
fi


datadir=$1
outdir=$2
K=20

if [ ! -d $2 ]; then
    mkdir $2
fi

for ((amp=0; amp<=100;amp=amp+10)); do
    echo "**** study with $amp amp threshold"
    if [ ! -d $2/$amp ]; then
        mkdir $2/$amp
    fi

    echo " * initializing study of main model"

    (python2.7 study.py $1/$amp --out $2/$amp --binary --K $K > $2/$amp/py-study.out 2> $2/$amp/py-study.err &)

    echo " * reformatting input for baseline"
    python to_list_form.py $1/$amp
    python to_sorec_list_form.py $1/$amp

    echo " * running baselines"
    mkdir $2/$amp/MF
    mkdir $2/$amp/SoRec
    ./ctr/ctr --directory $2/$amp/MF --user $1/$amp/users.dat --item $1/$amp/items.dat --num_factors $K
    ./ctr/ctr --directory $2/$amp/SoRec --user $1/$amp/users_sorec.dat --item $1/$amp/items_sorec.dat --num_factors $K

    echo " * evaluating baselines"
    python pred-n-rank_ctr.py $1/$amp $2/$amp/MF $K
    python pred-n-rank_sorec.py $1/$amp $2/$amp/SoRec $K
    python eval.py $2/$amp/MF/rankings.out $2/$amp/MF
    python eval.py $2/$amp/SoRec/rankings.out $2/$amp/SoRec

    echo "**** done with $amp!"
done
echo "all done"
