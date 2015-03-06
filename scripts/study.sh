#!/bin/bash

if [ "$#" -ne 4 ]; then
    echo "usage: ./study [data-dir] [output-dir] [K] [directed/undirected]"
    exit
fi


datadir=$1
outdir=$2
K=$3
directed=$4

echo "creating directory structure"
if [ -d $2 ]; then
    rm -rf $2
fi
mkdir $2

mkdir $2/spf
mkdir $2/pf
mkdir $2/sf
mkdir $2/pop

seed=948237247

cd ../src

echo " * initializing study of main model (this will launch multiple processes"
echo "   that will continue living after this bash script has completed)"

if [ "$directed" = "directed" ]; then
    # directed
    (./spf --data $1 --out $2/spf --directed --bias --svi --K $K --seed $seed --save_freq 1000 --conv_freq 100 --min_iter 2000 --max_iter 2000 --final_pass > $2/spf.out 2> $2/spf.err &)
    (./spf --data $1 --out $2/pf --directed --bias --svi --K $K --seed $seed --save_freq 1000 --conv_freq 100 --factor_only --min_iter 2000 --max_iter 2000 --final_pass > $2/pf.out 2> $2/pf.err &)
    (./spf --data $1 --out $2/sf --directed --bias --svi --K $K --seed $seed --save_freq 1000 --conv_freq 100 --social_only --min_iter 2000 --max_iter 2000 --final_pass > $2/sf.out 2> $2/sf.err &)
else
    # undirected
    (./spf --data $1 --out $2/spf --bias --svi --K $K --seed $seed --save_freq 1000 --conv_freq 100 --min_iter 2000 --max_iter 2000 --final_pass > $2/spf.out 2> $2/spf.err &)
    (./spf --data $1 --out $2/pf --bias --svi --K $K --seed $seed --save_freq 1000 --conv_freq 100 --factor_only --min_iter 2000 --max_iter 2000 --final_pass > $2/pf.out 2> $2/pf.err &)
    (./spf --data $1 --out $2/sf --bias --svi --K $K --seed $seed --save_freq 1000 --conv_freq 100 --social_only --min_iter 2000 --max_iter 2000 --final_pass > $2/sf.out 2> $2/sf.err &)
fi

(./pop --data $1 --out $2/pop > $2/pop.out 2> $2/pop.err &)

#echo " * reformatting input for MF comparisons"
#python mkdat/to_list_form.py $1
#if [ "$directed" = "directed" ]; then
#    # directed
#    python mkdat/to_sorec_list_form.py $1
#else
#    # undirected
#    python mkdat/to_sorec_list_form.py $1 undir
#fi
#
#echo " * fitting MF comparisons"
#mkdir $2/MF
#mkdir $2/SoRec
#./ctr/ctr --directory $2/MF --user $1/users.dat --item $1/items.dat --num_factors $K --b 1 --random_seed $seed #--lambda_u 0 --lambda_v 0
#./ctr/ctr --directory $2/SoRec --user $1/users_sorec.dat --item $1/items_sorec.dat --num_factors $K --b 1 --random_seed $seed #--lambda_u 0 --lambda_v 0
#
#echo " * evaluating MF comparisons"
#make mf
#./mf --data $1 --out $2/MF --K $K
#./mf --data $1 --out $2/SoRec --K $K
#
#mv $2/SoRec $2/SoRec-ctr

echo ""

echo ""
echo " * getting data ready for librec comparisons"
if [ "$directed" = "directed" ]; then
    # directed
    python ../scripts/to_librec_form.py $1
else
    # undirected
    python ../scripts/to_librec_form.py $1 undir
fi

echo " * fitting librec comparisons"
# config files!! (TODO)
for model in SoRec SocialMF TrustMF SoReg RSTE PMF TrustSVD MostPop BiasedMF
do
    echo $model
    echo "dataset.training.lins=$1/ratings.dat" > tmp
    echo "dataset.social.lins=$1/network.dat" >> tmp
    echo "dataset.testing.lins=$1/test.dat" >> tmp
    echo "recommender=$model" >> tmp
    echo "num.factors=$K" >> tmp
    if [ "$model" = "TrustSVD" ]; then
        echo "num.max.iter=50" >> tmp
    else
        echo "num.max.iter=100" >> tmp
    fi
    cat tmp ../conf/base.conf > ../conf/tmp.conf
    echo ""
    echo "CONF"
    head ../conf/tmp.conf
    echo ""
    time java -jar librec/librec.jar -c ../conf/tmp.conf
    mkdir $2/$model
    tail -n +2 Results/$model*prediction.txt > $2/$model/ratings.dat

    LINECOUNT=`wc -l $2/$model/ratings.dat | cut -f1 -d' '`

    if [[ $LINECOUNT != 0 ]]; then
        time ./librec_eval --data $1 --out $2/$model
    fi
done


echo "all done!"
