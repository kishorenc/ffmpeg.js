# Compile FFmpeg and all its dependencies to JavaScript.
# You need emsdk environment installed and activated, see:
# <https://kripken.github.io/emscripten-site/docs/getting_started/downloads.html>.

# To be built on emsdk 1.37.40

PRE_JS = build/pre.js
LIBRARY_JS = build/library.js
POST_JS_SYNC = build/post-sync.js
POST_JS_WORKER = build/post-worker.js

COMMON_FILTERS = aresample trim overlay null

COMMON_DEMUXERS = aac ac3 aiff amr ape asf au avi flac flv matroska mov m4v mp3 mpc mpc8 ogg pcm_alaw pcm_mulaw \
                  pcm_f64be pcm_f64le pcm_f32be pcm_f32le pcm_s32be pcm_s32le pcm_s24be pcm_s24le pcm_s16be pcm_s16le \
                  pcm_s8 pcm_u32be pcm_u32le pcm_u24be pcm_u24le pcm_u16be pcm_u16le pcm_u8 rm shorten tak tta wav wv \
                  xwma dsf

COMMON_DECODERS = aac aac_latm ac3 alac als amrnb amrwb amr_nb_at ape atrac1 atrac3 eac3 flac gsm gsm_ms mp1 mp1float mp2 mp2float mp3 \
                  mp3adu mp3adufloat mp3float mp3on4 mp3on4float mpc7 mpc8 opus ra_144 ra_288 ralf shorten tak tta \
                  vorbis wavpack wmalossless wmapro wmav1 wmav2 wmavoice \
                  pcm_alaw pcm_bluray pcm_dvd pcm_f32be pcm_f32le pcm_f64be pcm_f64le pcm_lxf pcm_mulaw pcm_s8 \
                  pcm_s8_planar pcm_s16be pcm_s16be_planar pcm_s16le pcm_s16le_planar pcm_s24be pcm_s24daud \
                  pcm_s24le pcm_s24le_planar pcm_s32be pcm_s32le pcm_s32le_planar pcm_u8 pcm_u16be pcm_u16le \
                  pcm_u24be pcm_u24le pcm_u32be pcm_u32le pcm_zork dsd_lsbf dsd_msbf dsd_lsbf_planar dsd_msbf_planar

COMMON_PARSERS = aac aac_latm ac3 cook dca flac gsm mpegaudio tak vorbis

COMMON_MUXERS = ac3 aiff asf avi mpeg1system mpeg1vcd mpeg1video h263 h264 mp3 mp4 mov mp2 ogg flv mjpeg vc1 flac wav \
                mpegps pcm_s16le pcm_s16be pcm_s8 pcm_u16le pcm_u16be pcm_u8 mpeg2vob mpeg2svcd mpeg2video mpeg2dvd null

COMMON_ENCODERS = aac ac3 h263 flv h263p h264 snow mpeg1video mp2 vc1 opus \
                  pcm_s16le pcm_s16be pcm_s8 pcm_u16le pcm_u16be pcm_u8 \
                  flac libmp3lame libx264 mpeg2video mpeg4 vorbis wmv1 wmv2

FFMPEG_MP4_BC = build/ffmpeg-mp4/ffmpeg.bc
FFMPEG_MP4_PC_PATH = ../x264/dist/lib/pkgconfig
MP4_SHARED_DEPS = \
	build/lame/dist/lib/libmp3lame.so \
	build/x264/dist/lib/libx264.so

all: mp4
mp4: ffmpeg-worker-mp4.js

clean: clean-js clean-wasm \
	clean-opus \
	clean-lame clean-x264 clean-ffmpeg-mp4
clean-js:
	rm -f -- dist/ffmpeg*.js
clean-wasm:
	rm -f -- dist/ffmpeg*.wasm
clean-opus:
	-cd build/opus && rm -rf dist && make clean
clean-lame:
	-cd build/lame && rm -rf dist && make clean
clean-x264:
	-cd build/x264 && rm -rf dist && make clean
clean-ffmpeg-mp4:
	-cd build/ffmpeg-mp4 && rm -f ffmpeg.bc && make clean

build/opus/configure:
	cd build/opus && ./autogen.sh

build/opus/dist/lib/libopus.so: build/opus/configure
	cd build/opus && \
	emconfigure ./configure \
		CFLAGS=-O3 \
		--prefix="$$(pwd)/dist" \
		--disable-static \
		--disable-doc \
		--disable-extra-programs \
		--disable-asm \
		--disable-rtcd \
		--disable-intrinsics \
		&& \
	emmake make -j8 && \
	emmake make install

# XXX(Kagami): host/build flags are used to enable cross-compiling
# (values must differ) but there should be some better way to achieve
# that: it probably isn't possible to build on x86 now.

build/lame/dist/lib/libmp3lame.so:
	cd build/lame && \
	git reset --hard && \
	patch -p1 < ../lame-configure.patch && \
	emconfigure ./configure \
		--prefix="$$(pwd)/dist" \
		--host=x86-none-linux \
		--disable-static \
		\
		--disable-gtktest \
		--disable-analyzer-hooks \
		--disable-decoder \
		--disable-frontend \
		&& \
	emmake make -j8 && \
	emmake make install

build/x264/dist/lib/libx264.so:
	cd build/x264 && \
	git reset --hard && \
	patch -p1 < ../x264-configure.patch && \
	emconfigure ./configure \
		--prefix="$$(pwd)/dist" \
		--extra-cflags="-Wno-unknown-warning-option" \
		--host=x86-none-linux \
		--disable-cli \
		--enable-shared \
		--disable-opencl \
		--disable-thread \
		--disable-asm \
		\
		--disable-avs \
		--disable-swscale \
		--disable-lavf \
		--disable-ffms \
		--disable-gpac \
		--disable-lsmash \
		&& \
	emmake make -j8 && \
	emmake make install

# TODO(Kagami): Emscripten documentation recommends to always use shared
# libraries but it's not possible in case of ffmpeg because it has
# multiple declarations of `ff_log2_tab` symbol. GCC builds FFmpeg fine
# though because it uses version scripts and so `ff_log2_tag` symbols
# are not exported to the shared libraries. Seems like `emcc` ignores
# them. We need to file bugreport to upstream. See also:
# - <https://kripken.github.io/emscripten-site/docs/compiling/Building-Projects.html>
# - <https://github.com/kripken/emscripten/issues/831>
# - <https://ffmpeg.org/pipermail/libav-user/2013-February/003698.html>
FFMPEG_COMMON_ARGS = \
	--cc=emcc \
	--enable-cross-compile \
	--target-os=none \
	--arch=x86 \
	--disable-runtime-cpudetect \
	--disable-asm \
	--disable-fast-unaligned \
	--disable-pthreads \
	--disable-w32threads \
	--disable-os2threads \
	--disable-debug \
	--disable-stripping \
	\
	--disable-all \
	--enable-ffmpeg \
	--enable-avcodec \
	--enable-avformat \
	--enable-avutil \
	--enable-swresample \
	--enable-swscale \
	--enable-avfilter \
	--disable-network \
	--disable-d3d11va \
	--disable-dxva2 \
	--disable-vaapi \
	--disable-vdpau \
	$(addprefix --enable-decoder=,$(COMMON_DECODERS)) \
	$(addprefix --enable-demuxer=,$(COMMON_DEMUXERS)) \
	--enable-protocol=file \
	--enable-protocol=pipe \
	$(addprefix --enable-filter=,$(COMMON_FILTERS)) \
	--disable-bzlib \
	--disable-iconv \
	--disable-libxcb \
	--disable-lzma \
	--disable-securetransport \
	--disable-xlib \
	--disable-zlib

build/ffmpeg-mp4/ffmpeg.bc: $(MP4_SHARED_DEPS)
	cd build/ffmpeg-mp4 && \
	git reset --hard && \
    patch -p1 < ../ffmpeg-disable-arc4random.patch && \
	patch -p1 < ../ffmpeg-always-use-newlines.patch && \
	EM_PKG_CONFIG_PATH=$(FFMPEG_MP4_PC_PATH) emconfigure ./configure \
		$(FFMPEG_COMMON_ARGS) \
		$(addprefix --enable-encoder=,$(COMMON_ENCODERS)) \
		$(addprefix --enable-muxer=,$(COMMON_MUXERS)) \
		$(addprefix --enable-parser=,$(COMMON_PARSERS)) \
		--enable-gpl \
		--enable-libmp3lame \
		--enable-libx264 \
		--extra-cflags="-I../lame/dist/include" \
		--extra-ldflags="-L../lame/dist/lib" \
		&& \
	emmake make -j8 && \
	cp ffmpeg ffmpeg.bc

# Compile bitcode to JavaScript.
# NOTE(Kagami): Bump heap size to 64M, default 16M is not enough even
# for simple tests and 32M tends to run slower than 64M.
EMCC_COMMON_ARGS = \
	--closure 0 \
	-s TOTAL_MEMORY=67108864 \
	-s ALLOW_MEMORY_GROWTH=1 \
	-s AGGRESSIVE_VARIABLE_ELIMINATION=1 \
	-s BINARYEN=1 \
	-s WASM=1 \
	-s MODULARIZE=1 \
	-s EXPORT_NAME=aconv \
	-s "BINARYEN_TRAP_MODE='clamp'" \
	-O3 --memory-init-file 0 \
	--pre-js $(PRE_JS) \
	-o $@

ffmpeg-worker-mp4.js: $(FFMPEG_MP4_BC)
	emcc $(FFMPEG_MP4_BC) $(MP4_SHARED_DEPS) \
    $(EMCC_COMMON_ARGS)
