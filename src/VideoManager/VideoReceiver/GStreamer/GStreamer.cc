/****************************************************************************
 *
 * (c) 2009-2023 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


/**
 * @file
 *   @brief QGC Video Streaming Initialization
 *   @author Gus Grubba <gus@auterion.com>
 */

#include "GStreamer.h"
#include "GstVideoReceiver.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QDebug>

QGC_LOGGING_CATEGORY(GStreamerLog, "GStreamerLog")
QGC_LOGGING_CATEGORY(GStreamerAPILog, "GStreamerAPILog")

static void qt_gst_log(GstDebugCategory * category,
                       GstDebugLevel      level,
                       const gchar      * file,
                       const gchar      * function,
                       gint               line,
                       GObject          * object,
                       GstDebugMessage  * message,
                       gpointer           data)
{
    Q_UNUSED(data);

    if (level > gst_debug_category_get_threshold(category)) {
        return;
    }

    QMessageLogger log(file, line, function);

    char* object_info = gst_info_strdup_printf("%" GST_PTR_FORMAT, static_cast<void*>(object));

    switch (level) {
    default:
    case GST_LEVEL_ERROR:
        log.critical(GStreamerAPILog, "%s %s", object_info, gst_debug_message_get(message));
        break;
    case GST_LEVEL_WARNING:
        log.warning(GStreamerAPILog, "%s %s", object_info, gst_debug_message_get(message));
        break;
    case GST_LEVEL_FIXME:
    case GST_LEVEL_INFO:
        log.info(GStreamerAPILog, "%s %s", object_info, gst_debug_message_get(message));
        break;
    case GST_LEVEL_DEBUG:
    case GST_LEVEL_LOG:
    case GST_LEVEL_TRACE:
    case GST_LEVEL_MEMDUMP:
        log.debug(GStreamerAPILog, "%s %s", object_info, gst_debug_message_get(message));
        break;
    }

    g_free(object_info);
    object_info = nullptr;
}

#if defined(Q_OS_IOS)
#include "gst_ios_init.h"
#endif

#include "VideoReceiver.h"

G_BEGIN_DECLS
// The static plugins we use
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
    GST_PLUGIN_STATIC_DECLARE(coreelements);
    GST_PLUGIN_STATIC_DECLARE(playback);
    GST_PLUGIN_STATIC_DECLARE(libav);
    GST_PLUGIN_STATIC_DECLARE(rtp);
    GST_PLUGIN_STATIC_DECLARE(rtsp);
    GST_PLUGIN_STATIC_DECLARE(udp);
    GST_PLUGIN_STATIC_DECLARE(videoparsersbad);
    GST_PLUGIN_STATIC_DECLARE(x264);
    GST_PLUGIN_STATIC_DECLARE(rtpmanager);
    GST_PLUGIN_STATIC_DECLARE(isomp4);
    GST_PLUGIN_STATIC_DECLARE(matroska);
    GST_PLUGIN_STATIC_DECLARE(mpegtsdemux);
    GST_PLUGIN_STATIC_DECLARE(opengl);
    GST_PLUGIN_STATIC_DECLARE(tcp);
#if defined(Q_OS_ANDROID)
    GST_PLUGIN_STATIC_DECLARE(androidmedia);
#elif defined(Q_OS_IOS)
    GST_PLUGIN_STATIC_DECLARE(applemedia);
#endif
#endif
    GST_PLUGIN_STATIC_DECLARE(qml6);
    GST_PLUGIN_STATIC_DECLARE(qgc);
G_END_DECLS

#if (defined(Q_OS_MAC) && defined(QGC_INSTALL_RELEASE)) || defined(Q_OS_WIN) || defined(Q_OS_LINUX)
static void qgcputenv(const QString& key, const QString& root, const QString& path)
{
    const QString value = root + path;
    qputenv(key.toStdString().c_str(), QByteArray(value.toStdString().c_str()));
}
#endif

void
GStreamer::blacklist(VideoDecoderOptions option)
{
    GstRegistry* registry = gst_registry_get();

    if (registry == nullptr) {
        qCCritical(GStreamerLog) << "Failed to get gstreamer registry.";
        return;
    }

    auto changeRank = [registry](const char* featureName, uint16_t rank) {
        GstPluginFeature* feature = gst_registry_lookup_feature(registry, featureName);
        if (feature == nullptr) {
            qCDebug(GStreamerLog) << "Failed to change ranking of feature. Featuer does not exist:" << featureName;
            return;
        }

        qCDebug(GStreamerLog) << "Changing feature (" << featureName << ") to use rank:" << rank;
        gst_plugin_feature_set_rank(feature, rank);
        gst_registry_add_feature(registry, feature);
        gst_object_unref(feature);
    };

    // Set rank for specific features
    changeRank("bcmdec", GST_RANK_NONE);

    switch (option) {
        case ForceVideoDecoderDefault:
            break;
        case ForceVideoDecoderSoftware: //se não funcionar, incluir ese  v4l2h265dec coisa da Qualcomm Snapdragon
            for(auto name : {"avdec_h265"}) { //original : for(auto name : {"avdec_h264", "avdec_h265", "amcviddec-h264"}) {
                changeRank(name, GST_RANK_PRIMARY + 1);
            }
            break;
        case ForceVideoDecoderVAAPI:
            for(auto name : {"vaapimpeg2dec", "vaapimpeg4dec", "vaapih263dec", "vaapih264dec", "vaapih265dec", "vaapivc1dec"}) {
                changeRank(name, GST_RANK_PRIMARY + 1);
            }
            break;
        case ForceVideoDecoderNVIDIA:
            for(auto name : {"nvh265dec", "nvh265sldec", "nvh264dec", "nvh264sldec"}) {
                changeRank(name, GST_RANK_PRIMARY + 1);
            }
            break;
        case ForceVideoDecoderDirectX3D:
            for(auto name : {"d3d11vp9dec", "d3d11h265dec", "d3d11h264dec"}) {
                changeRank(name, GST_RANK_PRIMARY + 1);
            }
            break;
        case ForceVideoDecoderVideoToolbox:
            changeRank("vtdec", GST_RANK_PRIMARY + 1);
            break;
        default:
            qCWarning(GStreamerLog) << "Can't handle decode option:" << option;
    }
}

void
GStreamer::initialize(int argc, char* argv[], int debuglevel)
{
    qRegisterMetaType<VideoReceiver::STATUS>("STATUS");

#ifdef Q_OS_MAC
    #ifdef QGC_INSTALL_RELEASE
        QString currentDir = QCoreApplication::applicationDirPath();
        qgcputenv("GST_PLUGIN_SCANNER",           currentDir, "/../Frameworks/GStreamer.framework/Versions/1.0/libexec/gstreamer-1.0/gst-plugin-scanner");
        qgcputenv("GTK_PATH",                     currentDir, "/../Frameworks/GStreamer.framework/Versions/Current");
        qgcputenv("GIO_EXTRA_MODULES",            currentDir, "/../Frameworks/GStreamer.framework/Versions/Current/lib/gio/modules");
        qgcputenv("GST_PLUGIN_SYSTEM_PATH_1_0",   currentDir, "/../Frameworks/GStreamer.framework/Versions/Current/lib/gstreamer-1.0");
        qgcputenv("GST_PLUGIN_SYSTEM_PATH",       currentDir, "/../Frameworks/GStreamer.framework/Versions/Current/lib/gstreamer-1.0");
        qgcputenv("GST_PLUGIN_PATH_1_0",          currentDir, "/../Frameworks/GStreamer.framework/Versions/Current/lib/gstreamer-1.0");
        qgcputenv("GST_PLUGIN_PATH",              currentDir, "/../Frameworks/GStreamer.framework/Versions/Current/lib/gstreamer-1.0");
    #endif
#elif defined(Q_OS_WIN)
    QString currentDir = QCoreApplication::applicationDirPath();
    qgcputenv("GST_PLUGIN_PATH", currentDir, "/gstreamer-plugins");
#elif defined(Q_OS_LINUX)
    const QString currentDir = QCoreApplication::applicationDirPath();
    qgcputenv("GST_REGISTRY_REUSE_PLUGIN_SCANNER", "no", "");
    qgcputenv("GST_PLUGIN_SCANNER", "/usr/lib/x86_64-linux-gnu", "/gstreamer1.0/gstreamer-1.0/gst-plugin-scanner");
    qgcputenv("GST_PTP_HELPER_1_0", "/usr/lib/x86_64-linux-gnu", "/gstreamer1.0/gstreamer-1.0/gst-ptp-helper");
    qgcputenv("GTK_PATH", "/usr", "");
    qgcputenv("GIO_EXTRA_MODULES", "/usr/lib/x86_64-linux-gnu", "/gio/modules");
    qgcputenv("GST_PLUGIN_SYSTEM_PATH_1_0", "/usr/lib/x86_64-linux-gnu", "/gstreamer-1.0");
    qgcputenv("GST_PLUGIN_SYSTEM_PATH", "/usr/lib/x86_64-linux-gnu", "/gstreamer-1.0");
    qgcputenv("GST_PLUGIN_PATH_1_0", currentDir, "../lib");
    qgcputenv("GST_PLUGIN_PATH", currentDir, "../lib");
#endif

    //-- If gstreamer debugging is not configured via environment then use internal QT logging
    if (qEnvironmentVariableIsEmpty("GST_DEBUG")) {
        gst_debug_set_default_threshold(static_cast<GstDebugLevel>(debuglevel));
        gst_debug_remove_log_function(gst_debug_log_default);
        gst_debug_add_log_function(qt_gst_log, nullptr, nullptr);
    }

    // Initialize GStreamer
#if defined(Q_OS_IOS)
    //-- iOS specific initialization
    gst_ios_pre_init();
#endif

    GError* error = nullptr;
    if (!gst_init_check(&argc, &argv, &error)) {
        qCCritical(GStreamerLog) << "gst_init_check() failed: " << error->message;
        g_error_free(error);
    }

    // The static plugins we use
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
    GST_PLUGIN_STATIC_REGISTER(coreelements);
    GST_PLUGIN_STATIC_REGISTER(playback);
    GST_PLUGIN_STATIC_REGISTER(libav);
    GST_PLUGIN_STATIC_REGISTER(rtp);
    GST_PLUGIN_STATIC_REGISTER(rtsp);
    GST_PLUGIN_STATIC_REGISTER(udp);
    GST_PLUGIN_STATIC_REGISTER(videoparsersbad);
    GST_PLUGIN_STATIC_REGISTER(x264);
    GST_PLUGIN_STATIC_REGISTER(rtpmanager);
    GST_PLUGIN_STATIC_REGISTER(isomp4);
    GST_PLUGIN_STATIC_REGISTER(matroska);
    GST_PLUGIN_STATIC_REGISTER(mpegtsdemux);
    GST_PLUGIN_STATIC_REGISTER(opengl);
    GST_PLUGIN_STATIC_REGISTER(tcp);

#if defined(Q_OS_ANDROID)
    GST_PLUGIN_STATIC_REGISTER(androidmedia);
#elif defined(Q_OS_IOS)
    GST_PLUGIN_STATIC_REGISTER(applemedia);
#endif
#endif

#if defined(Q_OS_IOS)
    gst_ios_post_init();
#endif

    GST_PLUGIN_STATIC_REGISTER(qml6);
    GST_PLUGIN_STATIC_REGISTER(qgc);
}

void*
GStreamer::createVideoSink(QObject* parent, QQuickItem* widget)
{
    Q_UNUSED(parent)

    GstElement* sink;

    if ((sink = gst_element_factory_make("qgcvideosinkbin", nullptr)) != nullptr) {
        g_object_set(sink, "widget", widget, NULL);
    } else {
        qCCritical(GStreamerLog) << "gst_element_factory_make('qgcvideosinkbin') failed";
    }

    return sink;
}

void
GStreamer::releaseVideoSink(void* sink)
{
    if (sink != nullptr) {
        gst_object_unref(GST_ELEMENT(sink));
    }
}

VideoReceiver*
GStreamer::createVideoReceiver(QObject* parent)
{
    Q_UNUSED(parent)
    return new GstVideoReceiver(nullptr);
}
