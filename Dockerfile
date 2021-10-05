FROM julia:1.6.2-alpine3.14
LABEL Name=mperhez/ntwctl-abm Version=0.0.1

ARG GIT_TOK

RUN apk add --no-cache python3 git freetype \
    gnu-libiconv fribidi libogg  fdk-aac-dev \ 
    ffmpeg-libs x265-libs zstd-dev tiff-dev gcompat qt5-qtbase-dev \
    && ln -s /usr/lib/libfreetype.so.6 /usr/lib/libfreetype.so \
    && ln -s /usr/lib/libbz2.so.1 /usr/lib/libbz2.so.1.0 \
    && ln -s /usr/lib/libx265.so.192 /usr/lib/libx265.so.169 \
    && ln -s /usr/lib/libjpeg.so.8.2.2 /usr/lib/libjpeg.so.62 \
    && ln -s /usr/lib/libfdk-aac.so.2 /usr/lib/libfdk-aac.so.1 \
    && git clone https://${GIT_TOK}@github.com/mperhez/network-fleet-abm.git \
    && julia network-fleet-abm/src/netManPkg.jl

WORKDIR network-fleet-abm
CMD ["julia","examples/simple.jl"]
