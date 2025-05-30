/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


/**
 * @file
 *   @brief Map Tile Cache
 *
 *   @author Gus Grubba <gus@auterion.com>
 *
 */
#include "QGCApplication.h"
#include "AppSettings.h"
#include "MapsSettings.h"
#include "SettingsManager.h"
#include "QGCMapEngine.h"
#include "QGCMapTileSet.h"
#include "QGCMapUrlEngine.h"
#include "QGCTileCacheWorker.h"

#include <QtCore/qapplicationstatic.h>
#include <QtCore/QStandardPaths>
#include <QtCore/QDir>

Q_DECLARE_METATYPE(QGCMapTask::TaskType)
Q_DECLARE_METATYPE(QGCTile)
Q_DECLARE_METATYPE(QList<QGCTile*>)

static QLocale kLocale;

#define CACHE_PATH_VERSION  "300"

struct stQGeoTileCacheQGCMapTypes {
    const char* name;
    QString type;
};

//-----------------------------------------------------------------------------

Q_APPLICATION_STATIC(QGCMapEngine, s_mapEngine);

QGCMapEngine* QGCMapEngine::instance()
{
    return s_mapEngine();
}

QGCMapEngine* getQGCMapEngine()
{
    return QGCMapEngine::instance();
}

//-----------------------------------------------------------------------------
QGCMapEngine::QGCMapEngine(QObject* parent)
    : QObject(parent)
    , _worker(new QGCCacheWorker(this))
    , _prunning(false)
    , _cacheWasReset(false)
{
    // qCDebug(QGeoTiledMappingManagerEngineQGCLog) << Q_FUNC_INFO << this;

    qRegisterMetaType<QGCMapTask::TaskType>();
    qRegisterMetaType<QGCTile>();
    qRegisterMetaType<QList<QGCTile*>>();
    connect(_worker, &QGCCacheWorker::updateTotals,   this, &QGCMapEngine::_updateTotals);
}

//-----------------------------------------------------------------------------
QGCMapEngine::~QGCMapEngine()
{
    (void) disconnect(_worker);
    _worker->quit();
    _worker->wait();

    // qCDebug(QGeoTiledMappingManagerEngineQGCLog) << Q_FUNC_INFO << this;
}

//-----------------------------------------------------------------------------
void
QGCMapEngine::_checkWipeDirectory(const QString& dirPath)
{
    QDir dir(dirPath);
    if (dir.exists(dirPath)) {
        _cacheWasReset = true;
        _wipeDirectory(dirPath);
    }
}

//-----------------------------------------------------------------------------
void
QGCMapEngine::_wipeOldCaches()
{
    QString oldCacheDir;
#ifdef __mobile__
    oldCacheDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)      + QLatin1String("/QGCMapCache55");
#else
    oldCacheDir = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + QStringLiteral("/QGCMapCache55");
#endif
    _checkWipeDirectory(oldCacheDir);
#ifdef __mobile__
    oldCacheDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)      + QLatin1String("/QGCMapCache100");
#else
    oldCacheDir = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + QStringLiteral("/QGCMapCache100");
#endif
    _checkWipeDirectory(oldCacheDir);
}

//-----------------------------------------------------------------------------
void
QGCMapEngine::init()
{
    //-- Delete old style caches (if present)
    _wipeOldCaches();
    //-- Figure out cache path
#ifdef __mobile__
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)      + QLatin1String("/QGCMapCache" CACHE_PATH_VERSION);
#else
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + QStringLiteral("/QGCMapCache" CACHE_PATH_VERSION);
#endif
    if(!QDir::root().mkpath(cacheDir)) {
        qWarning() << "Could not create mapping disk cache directory: " << cacheDir;
        cacheDir = QDir::homePath() + QStringLiteral("/.qgcmapscache/");
        if(!QDir::root().mkpath(cacheDir)) {
            qWarning() << "Could not create mapping disk cache directory: " << cacheDir;
            cacheDir.clear();
        }
    }
    _cachePath = cacheDir;
    if(!_cachePath.isEmpty()) {
        _cacheFile = kDbFileName;
        _worker->setDatabaseFile(_cachePath + "/" + _cacheFile);
        qDebug() << "Map Cache in:" << _cachePath << "/" << _cacheFile;
    } else {
        qCritical() << "Could not find suitable map cache directory.";
    }
    QGCMapTask* task = new QGCMapTask(QGCMapTask::taskInit);
    _worker->enqueueTask(task);
}

//-----------------------------------------------------------------------------
bool
QGCMapEngine::_wipeDirectory(const QString& dirPath)
{
    bool result = true;
    QDir dir(dirPath);
    if (dir.exists(dirPath)) {
        Q_FOREACH(QFileInfo info, dir.entryInfoList(QDir::NoDotAndDotDot | QDir::System | QDir::Hidden  | QDir::AllDirs | QDir::Files, QDir::DirsFirst)) {
            if (info.isDir()) {
                result = _wipeDirectory(info.absoluteFilePath());
            } else {
                result = QFile::remove(info.absoluteFilePath());
            }
            if (!result) {
                return result;
            }
        }
        result = dir.rmdir(dirPath);
    }
    return result;
}

//-----------------------------------------------------------------------------
void
QGCMapEngine::addTask(QGCMapTask* task)
{
    _worker->enqueueTask(task);
}

//-----------------------------------------------------------------------------
void
QGCMapEngine::cacheTile(const QString& type, int x, int y, int z, const QByteArray& image, const QString &format, qulonglong set)
{
    QString hash = getTileHash(type, x, y, z);
    cacheTile(type, hash, image, format, set);
}

//-----------------------------------------------------------------------------
void
QGCMapEngine::cacheTile(const QString& type, const QString& hash, const QByteArray& image, const QString& format, qulonglong set)
{
    AppSettings* appSettings = qgcApp()->toolbox()->settingsManager()->appSettings();
    //-- If we are allowed to persist data, save tile to cache
    if(!appSettings->disableAllPersistence()->rawValue().toBool()) {
        QGCSaveTileTask* task = new QGCSaveTileTask(new QGCCacheTile(hash, image, format, type, set));
        _worker->enqueueTask(task);
    }
}

//-----------------------------------------------------------------------------
QString
QGCMapEngine::getTileHash(const QString& type, int x, int y, int z)
{
    int hash = UrlFactory::hashFromProviderType(type);
    return QString::asprintf("%010d%08d%08d%03d", hash, x, y, z);
}

//-----------------------------------------------------------------------------
QString
QGCMapEngine::tileHashToType(const QString& tileHash)
{
    int providerHash = tileHash.mid(0,10).toInt();
    return UrlFactory::providerTypeFromHash(providerHash);
}

//-----------------------------------------------------------------------------
	QGCFetchTileTask*
QGCMapEngine::createFetchTileTask(const QString& type, int x, int y, int z)
{
	QString hash = getTileHash(type, x, y, z);
	QGCFetchTileTask* task = new QGCFetchTileTask(hash);
	return task;
}

//-----------------------------------------------------------------------------
	QGCTileSet
QGCMapEngine::getTileCount(int zoom, double topleftLon, double topleftLat, double bottomRightLon, double bottomRightLat, const QString& mapType)
{
	if(zoom <  1) zoom = 1;
	if(zoom > MAX_MAP_ZOOM) zoom = MAX_MAP_ZOOM;

    return UrlFactory::getTileCount(zoom, topleftLon, topleftLat, bottomRightLon, bottomRightLat, mapType);
}


//-----------------------------------------------------------------------------
QStringList
QGCMapEngine::getMapNameList()
{
    return UrlFactory::getProviderTypes();
}

//-----------------------------------------------------------------------------
quint32
QGCMapEngine::getMaxDiskCache()
{
    return qgcApp()->toolbox()->settingsManager()->mapsSettings()->maxCacheDiskSize()->rawValue().toUInt();
}

//-----------------------------------------------------------------------------
quint32
QGCMapEngine::getMaxMemCache()
{
    return qgcApp()->toolbox()->settingsManager()->mapsSettings()->maxCacheMemorySize()->rawValue().toUInt();
}

//-----------------------------------------------------------------------------
void
QGCMapEngine::_updateTotals(quint32 totaltiles, quint64 totalsize, quint32 defaulttiles, quint64 defaultsize)
{
    emit updateTotals(totaltiles, totalsize, defaulttiles, defaultsize);
    quint64 maxSize = static_cast<quint64>(getMaxDiskCache()) * 1024L * 1024L;
    if(!_prunning && defaultsize > maxSize) {
        //-- Prune Disk Cache
        _prunning = true;
        QGCPruneCacheTask* task = new QGCPruneCacheTask(defaultsize - maxSize);
        connect(task, &QGCPruneCacheTask::pruned, this, &QGCMapEngine::_pruned);
        addTask(task);
    }
}

//-----------------------------------------------------------------------------
QGCCreateTileSetTask::~QGCCreateTileSetTask()
{
    //-- If not sent out, delete it
    if(!_saved && _tileSet)
        delete _tileSet;
}

// Resolution math: https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames#Resolution_and_Scale
