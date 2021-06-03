#!/usr/bin/env bash

mkdir -p iso

docker run -it --rm \
       -v $PWD/iso:/iso \
       -v $PWD/mkimg.lima.sh:/home/build/aports/scripts/mkimg.lima.sh:ro \
       -v $PWD/genapkovl-lima.sh:/home/build/aports/scripts/genapkovl-lima.sh:ro \
       mkimg \
       sh ./mkimage.sh \
       --tag dev \
       --outdir /iso \
       --arch x86_64 \
       --repository http://dl-cdn.alpinelinux.org/alpine/v3.13/main \
       --repository http://dl-cdn.alpinelinux.org/alpine/v3.13/community \
       --profile lima
