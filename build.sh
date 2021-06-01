#!/usr/bin/env bash

mkdir -p iso

docker run -it --rm -v $PWD/iso:/iso mkimg \
       sh ./mkimage.sh \
       --tag dev \
       --outdir /iso \
       --arch x86_64 \
       --repository http://dl-cdn.alpinelinux.org/alpine/v3.13/main \
       --profile virt
