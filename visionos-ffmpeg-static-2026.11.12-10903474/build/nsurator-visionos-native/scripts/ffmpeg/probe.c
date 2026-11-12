/* Link and runtime probe for the visionOS FFmpeg artifact.
 * Built by scripts/build_ffmpeg_visionos.sh for every slice and linked the way
 * player-core's Package.swift links in static mode; on the simulator slice it is
 * also run inside an already booted visionOS simulator. */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <libavcodec/avcodec.h>
#include <libavfilter/avfilter.h>
#include <libavformat/avformat.h>
#include <libavutil/channel_layout.h>
#include <libavutil/hwcontext.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>
#include <dav1d/dav1d.h>
#include <libbluray/bluray.h>

/* 0.1 s of 8 kHz mono 16-bit PCM in a WAV container, read through a custom
 * AVIOContext the way player-core feeds FFmpeg (no files, no network). */
#define SAMPLES 800
static uint8_t wav[44 + SAMPLES * 2];
static size_t wav_pos;

static void put32(uint8_t *p, uint32_t v) { p[0] = v; p[1] = v >> 8; p[2] = v >> 16; p[3] = v >> 24; }
static void put16(uint8_t *p, uint16_t v) { p[0] = v; p[1] = v >> 8; }

static int read_packet(void *opaque, uint8_t *buf, int size) {
    (void)opaque;
    size_t left = sizeof(wav) - wav_pos;
    if (left == 0)
        return AVERROR_EOF;
    if ((size_t)size > left)
        size = (int)left;
    memcpy(buf, wav + wav_pos, (size_t)size);
    wav_pos += (size_t)size;
    return size;
}

static int decode_wav(void) {
    memcpy(wav, "RIFF", 4);
    put32(wav + 4, sizeof(wav) - 8);
    memcpy(wav + 8, "WAVEfmt ", 8);
    put32(wav + 16, 16);
    put16(wav + 20, 1);
    put16(wav + 22, 1);
    put32(wav + 24, 8000);
    put32(wav + 28, 16000);
    put16(wav + 32, 2);
    put16(wav + 34, 16);
    memcpy(wav + 36, "data", 4);
    put32(wav + 40, SAMPLES * 2);
    for (int i = 0; i < SAMPLES; i++)
        put16(wav + 44 + i * 2, (uint16_t)(int16_t)((i % 40) * 800 - 16000));

    int decoded = -1;
    unsigned char *iobuf = av_malloc(4096);
    AVIOContext *io = avio_alloc_context(iobuf, 4096, 0, NULL, read_packet, NULL, NULL);
    AVFormatContext *fmt = avformat_alloc_context();
    if (!io || !fmt)
        return -1;
    fmt->pb = io;
    if (avformat_open_input(&fmt, NULL, NULL, NULL) < 0)
        goto free_io; /* fmt is freed by avformat_open_input on failure */
    if (avformat_find_stream_info(fmt, NULL) < 0 || fmt->nb_streams != 1)
        goto close;
    const AVCodec *dec = avcodec_find_decoder(fmt->streams[0]->codecpar->codec_id);
    AVCodecContext *ctx = avcodec_alloc_context3(dec);
    avcodec_parameters_to_context(ctx, fmt->streams[0]->codecpar);
    if (avcodec_open2(ctx, dec, NULL) < 0) {
        avcodec_free_context(&ctx);
        goto close;
    }
    SwrContext *swr = NULL;
    AVChannelLayout mono = AV_CHANNEL_LAYOUT_MONO;
    if (swr_alloc_set_opts2(&swr, &mono, AV_SAMPLE_FMT_FLT, 48000, &ctx->ch_layout, ctx->sample_fmt,
                            ctx->sample_rate, 0, NULL) < 0 || swr_init(swr) < 0) {
        swr_free(&swr);
        avcodec_free_context(&ctx);
        goto close;
    }
    AVPacket *pkt = av_packet_alloc();
    AVFrame *frame = av_frame_alloc();
    static float out[8192];
    decoded = 0;
    while (av_read_frame(fmt, pkt) >= 0) {
        if (avcodec_send_packet(ctx, pkt) >= 0) {
            while (avcodec_receive_frame(ctx, frame) >= 0) {
                uint8_t *o = (uint8_t *)out;
                if (swr_convert(swr, &o, 8192, (const uint8_t **)frame->extended_data, frame->nb_samples) < 0)
                    decoded = -1000000;
                decoded += frame->nb_samples;
            }
        }
        av_packet_unref(pkt);
    }
    av_frame_free(&frame);
    av_packet_free(&pkt);
    swr_free(&swr);
    avcodec_free_context(&ctx);
close:
    avformat_close_input(&fmt);
free_io:
    av_freep(&io->buffer);
    avio_context_free(&io);
    return decoded;
}

int main(void) {
    int major = 0, minor = 0, micro = 0, failures = 0;
    void *opaque = NULL;
    unsigned demuxers = 0;
    while (av_demuxer_iterate(&opaque))
        demuxers++;
    bd_get_version(&major, &minor, &micro);

    const AVCodec *av1 = avcodec_find_decoder_by_name("libdav1d");
    int av1_open = -1;
    if (av1) {
        AVCodecContext *c = avcodec_alloc_context3(av1);
        av1_open = avcodec_open2(c, av1, NULL);
        avcodec_free_context(&c);
    }
    AVBufferRef *hw = NULL;
    int vt = av_hwdevice_ctx_create(&hw, AV_HWDEVICE_TYPE_VIDEOTOOLBOX, NULL, NULL, 0);
    av_buffer_unref(&hw);
    int wav_samples = decode_wav();

    printf("avformat %d.%d.%d, dav1d %s, libbluray %d.%d.%d, %u demuxers, scale_vt %s, swscale yuv420p %s; "
           "libdav1d open %s, VideoToolbox device %s, WAV via custom AVIO %d/%d samples\n",
           (int)(avformat_version() >> 16), (int)((avformat_version() >> 8) & 0xff), (int)(avformat_version() & 0xff),
           dav1d_version(), major, minor, micro, demuxers, avfilter_get_by_name("scale_vt") ? "yes" : "no",
           sws_isSupportedInput(AV_PIX_FMT_YUV420P) ? "yes" : "no",
           av1_open == 0 ? "ok" : "FAILED", vt == 0 ? "ok" : "FAILED", wav_samples, SAMPLES);
    failures += av1_open != 0;
    failures += vt != 0;
    failures += wav_samples != SAMPLES;
    return failures ? 1 : 0;
}
