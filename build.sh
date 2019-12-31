#!/bin/bash

ff_src_dir="./"

if [[ "" == $FFMPEG_JOBS ]]; then
    cpu_num=$(grep -c ^processor /proc/cpuinfo 2>/dev/null);
    cpu_num=${cpu_num:- "1"};
    export FFMPEG_JOBS="--jobs=${cpu_num}"
fi

echo $FFMPEG_JOBS;
#当前目录
ff_current_dir=$(pwd -P)
ff_build_dir="${ff_current_dir}/_build"
ff_release_dir="${ff_current_dir}/_release"

echo "start to build the tools for transcode system:"
echo "current_dir: ${ff_current_dir}"
echo "build_dir: ${ff_build_dir}"
echo "release_dir: ${ff_release_dir}"
echo "ffmpeg_jobs: ${FFMPEG_JOBS}"

mkdir -p ${ff_build_dir}
mkdir -p ${ff_release_dir}


# yasm for libx264
ff_yasm_bin=${ff_release_dir}/bin/yasm
if [[ -f ${ff_yasm_bin} ]]; then
    echo "yasm is ok"
else
    echo "build yasm-1.3.0"
    cd $ff_current_dir &&
    rm -rf yasm-1.3.0 && unzip -q ${ff_src_dir}/yasm-1.3.0.zip &&
    cd yasm-1.3.0  && chmod -R 777 * && ./configure --prefix=${ff_release_dir} &&
    make && make install
    ret=$?; if [[ 0 -ne ${ret} ]]; then echo "build yasm-1.3.0 failed"; exit 1; fi
fi

#将yasm添加到path，以便x264直接使用yasm
#也可以在ffmpeg配置时指定路径
export PATH=${PATH}:${ff_release_dir}/bin

# libfdk-aac
if [[ -f ${ff_release_dir}/lib/libfdk-aac.a ]]; then
    echo "libfdk_aac is ok"
else
    echo "build fdk-aac-2.0.0"fdk-aac-2.0.0
    cd $ff_current_dir &&
    rm -rf fdk-aac-2.0.0 && unzip -q ${ff_src_dir}/fdk-aac-2.0.0.zip &&
    cd fdk-aac-2.0.0 && chmod -R 777 * && bash autogen.sh && ./configure --prefix=${ff_release_dir} --enable-static && make ${FFMPEG_JOBS} && make install
    ret=$?; if [[ 0 -ne ${ret} ]]; then echo "build fdk-aac-0.1.6 failed"; exit 1; fi
fi


# lame-3.99
if [[ -f ${ff_release_dir}/lib/libmp3lame.a ]]; then
    echo "libmp3lame is ok"
else
    echo "build lame-3.99.5"
    cd $ff_current_dir &&
    rm -rf lame-3.99.5 && unzip -q ${ff_src_dir}/lame-3.99.5.zip &&
    cd lame-3.99.5  && chmod -R 777 * && ./configure --prefix=${ff_release_dir} --enable-static && make ${FFMPEG_JOBS} && make install
    ret=$?; if [[ 0 -ne ${ret} ]]; then echo "build lame-3.99.5 failed"; exit 1; fi
fi

# speex-1.2rc1
if [[ -f ${ff_release_dir}/lib/libspeex.a ]]; then
    echo "libspeex is ok"
else
    echo "build speex-1.2rc1"
    cd $ff_current_dir &&
    rm -rf speex-1.2rc1 && unzip -q ${ff_src_dir}/speex-1.2rc1.zip &&
    cd speex-1.2rc1  && chmod -R 777 * && ./configure --prefix=${ff_release_dir} --enable-static && make ${FFMPEG_JOBS} && make install
    ret=$?; if [[ 0 -ne ${ret} ]]; then echo "build speex-1.2rc1 failed"; exit 1; fi
fi


# x264
if [[ -f ${ff_release_dir}/lib/libx264.a ]]; then
    echo "x264 is ok"
else
    echo "build x264"
    cd $ff_current_dir &&
    rm -rf x264-snapshot-20190902-2245-stable && unzip -q ${ff_src_dir}/x264-snapshot-20190902-2245-stable.zip &&
    cd x264-snapshot-20190902-2245-stable &&
    chmod -R 777 * &&
    ./configure --prefix=${ff_release_dir} --disable-opencl --bit-depth=8 \
        --enable-static --disable-avs  --disable-swscale  --disable-lavf \
        --disable-ffms  --disable-gpac --disable-asm &&
    make ${FFMPEG_JOBS} && make install
    ret=$?; if [[ 0 -ne ${ret} ]]; then echo "build x264 failed"; exit 1; fi
fi

# x265
if [[ -f ${ff_release_dir}/lib/libx265.a ]]; then
    echo "x265 is ok"
else
    echo "build x265"
    cd $ff_current_dir &&
    rm -rf x265_3.1.1 && unzip -q ${ff_src_dir}/x265_3.1.1.zip &&
    cd x265_3.1.1/build/linux  && chmod -R 777 * &&
    cmake -G "Unix Makefiles" -BIN_INSTALL_DIR=${ff_release_dir} -DCMAKE_INSTALL_PREFIX=${ff_release_dir}  -DENABLE_SHARED:bool=off ../../source  &&
    make ${FFMPEG_JOBS} && make install
    ret=$?; if [[ 0 -ne ${ret} ]]; then echo "build x265 failed"; exit 1; fi
fi


# ffmpeg
if [[ -f ${ff_release_dir}/bin/ffmpeg ]]; then
    echo "ffmpeg-4.2 is ok"
else
    echo "build ffmpeg-4.2"
    cd $ff_current_dir &&
    rm -rf ffmpeg-4.2 && unzip -q ${ff_src_dir}/ffmpeg-4.2.zip &&
    echo "remove all so to force the ffmpeg to build in static" &&
    rm -f ${ff_release_dir}/lib/*.so* &&
    echo "export the dir to enable the build command canbe use." &&
    export ffmpeg_exported_release_dir=${ff_release_dir} &&
    cd ffmpeg-4.2 &&
    chmod -R 777 * &&
    export PKG_CONFIG_PATH=${ff_release_dir}/lib/pkgconfig:$PKG_CONFIG_PATH &&
    echo $PKG_CONFIG_PATH &&
    ./configure \
        --pkg-config-flags="--static" \
        --enable-gpl --enable-nonfree \
        --prefix=${ff_release_dir} --cc= \
        --enable-static --disable-shared --disable-debug \
        --extra-cflags='-I${ffmpeg_exported_release_dir}/include' \
        --extra-ldflags='-L${ffmpeg_exported_release_dir}/lib -lm -ldl' \
        --disable-ffplay   --disable-doc \
        --enable-postproc --enable-bzlib --enable-zlib --enable-parsers \
        --enable-libx264 --enable-libx265 --enable-libmp3lame --enable-libfdk-aac --enable-libspeex\
        --enable-pthreads --extra-libs=-lpthread  \
        --enable-encoders --enable-decoders --enable-avfilter --enable-muxers --enable-demuxers &&
    make ${FFMPEG_JOBS} && make install
    ret=$?; if [[ 0 -ne ${ret} ]]; then echo "build ffmpeg failed"; exit 1; fi
fi

#安装工具
if [[ -f ${ff_release_dir}/bin/qt-faststart ]]; then
    echo "qt-faststart is ok"
else
  cd ${ff_current_dir}/ffmpeg-4.2 && make tools/qt-faststart
  ret=$?; if [[ 0 -ne ${ret} ]]; then echo "build qt-faststart failed"; exit 1; fi
  cp ${ff_current_dir}/ffmpeg-4.2/tools/qt-faststart ${ff_release_dir}/bin/qt-faststart
fi

