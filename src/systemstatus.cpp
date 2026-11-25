#include "systemstatus.h"

#include <QColor>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusVariant>
#include <QDBusReply>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>
#include <KIdleTime>

namespace
{
const QString kSink = QStringLiteral("@DEFAULT_AUDIO_SINK@");
const QString kPowerSupply = QStringLiteral("/sys/class/power_supply");
// PolicyAgent inhibition type for screen dimming/locking.
constexpr uint kChangeScreenSettings = 4;

QString readFile(const QString &path)
{
    QFile f(path);
    return f.open(QIODevice::ReadOnly) ? QString::fromUtf8(f.readAll()) : QString();
}

QDBusMessage notifyCall(const QString &method)
{
    return QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.Notifications"), QStringLiteral("/org/freedesktop/Notifications"),
                                          QStringLiteral("org.freedesktop.Notifications"), method);
}

QDBusMessage screenSaverCall(const QString &method)
{
    return QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.ScreenSaver"), QStringLiteral("/ScreenSaver"),
                                          QStringLiteral("org.freedesktop.ScreenSaver"), method);
}

// Plain messages skip QDBusInterface's introspection round trip; reads never block the UI.
void callAsync(QObject *context, const QDBusMessage &msg, std::function<void(const QDBusMessage &)> done, QDBusConnection bus = QDBusConnection::sessionBus())
{
    auto *watcher = new QDBusPendingCallWatcher(bus.asyncCall(msg, 2000), context);
    QObject::connect(watcher, &QDBusPendingCallWatcher::finished, context, [watcher, done] {
        done(watcher->reply());
        watcher->deleteLater();
    });
}

uint callForCookie(const QDBusMessage &msg)
{
    const QDBusReply<uint> reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 2000);
    return reply.isValid() ? reply.value() : 0;
}
}

SystemStatus::SystemStatus(QObject *parent)
    : QObject(parent)
{
    refresh();
    // Chargers and batteries announce changes through UPower, so plugging in shows at once instead
    // of at the next poll. An empty path takes every power device, so isChargerChange() drops the
    // routine reports (charge and draw, every device, every few seconds).
    QDBusConnection::systemBus().connect(QStringLiteral("org.freedesktop.UPower"), QString(), QStringLiteral("org.freedesktop.DBus.Properties"),
                                         QStringLiteral("PropertiesChanged"), this, SLOT(onPowerChanged(QString, QVariantMap, QStringList)));
    QDBusConnection::sessionBus().connect(QStringLiteral("org.kde.ScreenBrightness"), QStringLiteral("/org/kde/ScreenBrightness"),
                                          QStringLiteral("org.kde.ScreenBrightness"), QStringLiteral("BrightnessChanged"), this,
                                          SLOT(onBrightnessChanged(QString, int, QString, QString)));

    auto *idle = KIdleTime::instance();
    idle->addIdleTimeout(60 * 1000);
    connect(idle, &KIdleTime::timeoutReached, this, [this, idle] {
        m_userIdle = true;
        Q_EMIT changed();
        idle->catchNextResumeEvent();
    });
    connect(idle, &KIdleTime::resumingFromIdle, this, [this] {
        m_userIdle = false;
        Q_EMIT changed();
    });
}

void SystemStatus::onBrightnessChanged(const QString &display, int value, const QString &, const QString &)
{
    const auto cached = m_maxBrightness.constFind(display);
    if (cached != m_maxBrightness.cend()) {
        if (*cached > 0)
            Q_EMIT brightnessChanged(qRound(value * 100.0 / *cached));
        return;
    }
    auto get = QDBusMessage::createMethodCall(QStringLiteral("org.kde.ScreenBrightness"), QStringLiteral("/org/kde/ScreenBrightness/") + display,
                                              QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"));
    get << QStringLiteral("org.kde.ScreenBrightness.Display") << QStringLiteral("MaxBrightness");
    callAsync(this, get, [this, display, value](const QDBusMessage &reply) {
        const int top = !reply.arguments().isEmpty() ? reply.arguments().first().value<QDBusVariant>().variant().toInt() : 0;
        if (top > 0) {
            m_maxBrightness.insert(display, top);
            Q_EMIT brightnessChanged(qRound(value * 100.0 / top));
        }
    });
}

SystemStatus::~SystemStatus()
{
    if (m_dndCookie)
        QDBusConnection::sessionBus().send(notifyCall(QStringLiteral("UnInhibit")) << m_dndCookie);
    if (m_awakeCookie)
        QDBusConnection::sessionBus().send(screenSaverCall(QStringLiteral("UnInhibit")) << m_awakeCookie);
}

std::optional<std::pair<int, bool>> SystemStatus::parseWpctlVolume(const QString &output)
{
    static const QRegularExpression re(QStringLiteral("^Volume:\\s+([0-9.]+)(\\s+\\[MUTED\\])?"));
    const auto m = re.match(output.trimmed());
    if (!m.hasMatch())
        return std::nullopt;
    return std::pair{qRound(m.captured(1).toDouble() * 100), m.hasCaptured(2)};
}

bool SystemStatus::parseNmcliRadio(const QString &output)
{
    return output.trimmed() == QLatin1String("enabled");
}

bool SystemStatus::parseBluetoothPowered(const QString &output)
{
    static const QRegularExpression re(QStringLiteral("^\\s*Powered:\\s*yes\\s*$"), QRegularExpression::MultilineOption);
    return re.match(output).hasMatch();
}

std::pair<int, bool> SystemStatus::parseBattery(const QString &capacity, const QString &status)
{
    // Plugged in, not just "Charging": a full battery on the charger reports "Full" or "Not charging".
    return {capacity.trimmed().toInt(), status.trimmed() != QLatin1String("Discharging")};
}

bool SystemStatus::dndUntilActive(const QString &until, const QDateTime &now)
{
    const auto when = QDateTime::fromString(until.trimmed(), Qt::ISODate);
    return when.isValid() && when > now;
}

void SystemStatus::run(const QString &program, const QStringList &args, std::function<void(const QString &)> done)
{
    auto *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [proc, done] {
        if (done)
            done(QString::fromUtf8(proc->readAllStandardOutput()));
        proc->deleteLater();
    });
    proc->start(program, args);
}

void SystemStatus::refresh()
{
    readBattery();
    readDnd();
    readKeepAwake();
    readWifi();
    readBluetooth();
    run(QStringLiteral("wpctl"), {QStringLiteral("get-volume"), kSink}, [this](const QString &out) {
        if (const auto v = parseWpctlVolume(out)) {
            m_volume = v->first;
            m_muted = v->second;
            Q_EMIT changed();
        }
    });
}

void SystemStatus::readWifi()
{
    auto get = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.NetworkManager"), QStringLiteral("/org/freedesktop/NetworkManager"),
                                              QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"));
    get << QStringLiteral("org.freedesktop.NetworkManager") << QStringLiteral("WirelessEnabled");
    callAsync(this, get, [this](const QDBusMessage &reply) {
        if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
            m_wifi = reply.arguments().first().value<QDBusVariant>().variant().toBool();
            Q_EMIT changed();
            return;
        }
        run(QStringLiteral("nmcli"), {QStringLiteral("radio"), QStringLiteral("wifi")}, [this](const QString &out) {
            m_wifi = parseNmcliRadio(out);
            Q_EMIT changed();
        });
    }, QDBusConnection::systemBus());
}

void SystemStatus::readBluetooth()
{
    auto get = QDBusMessage::createMethodCall(QStringLiteral("org.bluez"), QStringLiteral("/org/bluez/hci0"),
                                              QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"));
    get << QStringLiteral("org.bluez.Adapter1") << QStringLiteral("Powered");
    callAsync(this, get, [this](const QDBusMessage &reply) {
        if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
            m_bluetooth = reply.arguments().first().value<QDBusVariant>().variant().toBool();
            Q_EMIT changed();
            return;
        }
        run(QStringLiteral("bluetoothctl"), {QStringLiteral("show")}, [this](const QString &out) {
            m_bluetooth = parseBluetoothPowered(out);
            Q_EMIT changed();
        });
    }, QDBusConnection::systemBus());
}

QString SystemStatus::batteryDir()
{
    if (m_batteryProbed)
        return m_batteryDir;
    m_batteryProbed = true;
    const QDir dir(kPowerSupply);
    for (const QString &name : dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name)) {
        const QString path = dir.filePath(name) + QLatin1Char('/');
        if (readFile(path + QStringLiteral("type")).trimmed() == QLatin1String("Battery") && QFile::exists(path + QStringLiteral("capacity"))) {
            m_batteryDir = path;
            break;
        }
    }
    return m_batteryDir;
}

bool SystemStatus::isChargerChange(const QVariantMap &changed)
{
    return changed.contains(QStringLiteral("Online")) || changed.contains(QStringLiteral("State")) || changed.contains(QStringLiteral("OnBattery"));
}

void SystemStatus::onPowerChanged(const QString &, const QVariantMap &changed, const QStringList &)
{
    if (!isChargerChange(changed))
        return;
    readBattery();
    // The battery's own status and draw settle a moment after the charger changes.
    QTimer::singleShot(1500, this, &SystemStatus::readBattery);
}

bool SystemStatus::pluggedIn(const QList<std::pair<QString, bool>> &supplies, const QString &batteryStatus)
{
    bool anyCharger = false;
    for (const auto &[type, online] : supplies) {
        if (type != QLatin1String("Mains") && type != QLatin1String("USB"))
            continue;
        anyCharger = true;
        if (online)
            return true;
    }
    return anyCharger ? false : batteryStatus.trimmed() != QLatin1String("Discharging");
}

void SystemStatus::readBattery()
{
    // DYNAMIC_ISLAND_BATTERY=12 pretends the battery is at 12% and unplugged, to preview the low-battery glance.
    const QString fake = qEnvironmentVariable("DYNAMIC_ISLAND_BATTERY");
    const QString bat = fake.isEmpty() ? batteryDir() : QString();
    const auto [capacity, charging] = !fake.isEmpty() ? parseBattery(fake, QStringLiteral("Discharging"))
                                      : !bat.isEmpty() ? parseBattery(readFile(bat + QStringLiteral("capacity")), readFile(bat + QStringLiteral("status")))
                                                       : std::pair{-1, false};
    // No battery (a desktop): -1 keeps it out of the pill instead of reading as 0%.
    m_battery = fake.isEmpty() && bat.isEmpty() ? -1 : capacity;
    m_charging = charging;
    if (fake.isEmpty()) {
        // The charger's own flag flips the moment it's plugged or pulled; the battery's status lags.
        QList<std::pair<QString, bool>> supplies;
        const QDir dir(kPowerSupply);
        for (const QString &name : dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot))
            supplies.append({readFile(dir.filePath(name) + QStringLiteral("/type")).trimmed(), readFile(dir.filePath(name) + QStringLiteral("/online")).trimmed() == QLatin1String("1")});
        m_charging = pluggedIn(supplies, bat.isEmpty() ? QString() : readFile(bat + QStringLiteral("status")));
    }
    m_batteryState = !fake.isEmpty() ? QStringLiteral("Discharging") : bat.isEmpty() ? QString() : readFile(bat + QStringLiteral("status")).trimmed();
    // Energy (µWh, µW) on most laptops; charge (µAh, µA) on some.
    const bool energy = !bat.isEmpty() && QFile::exists(bat + QStringLiteral("energy_now"));
    auto num = [](const QString &path) { return readFile(path).trimmed().toLongLong(); };
    m_batteryMinutes = !fake.isEmpty() || bat.isEmpty() ? -1
        : energy ? minutesLeft(m_batteryState, num(bat + QStringLiteral("energy_now")), num(bat + QStringLiteral("energy_full")), num(bat + QStringLiteral("power_now")))
                 : minutesLeft(m_batteryState, num(bat + QStringLiteral("charge_now")), num(bat + QStringLiteral("charge_full")), num(bat + QStringLiteral("current_now")));
    Q_EMIT changed();
}

int SystemStatus::minutesLeft(const QString &status, qint64 now, qint64 full, qint64 rate)
{
    rate = qAbs(rate);
    if (rate <= 0 || now < 0)
        return -1;
    const QString s = status.trimmed();
    double hours = -1;
    if (s == QLatin1String("Discharging"))
        hours = double(now) / double(rate);
    else if (s == QLatin1String("Charging") && full > now)
        hours = double(full - now) / double(rate);
    // A reading far beyond a day is the draw settling, not a real estimate.
    return hours < 0 || hours > 48 ? -1 : int(hours * 60 + 0.5);
}

bool SystemStatus::silenced(bool ownDnd, bool trayDnd, bool inhibited, bool ignoreHolds)
{
    return ownDnd || trayDnd || (inhibited && !ignoreHolds);
}

void SystemStatus::readDnd()
{
    // Plasma's own DND (tray) lives in plasmanotifyrc; other apps' holds show up as Inhibited.
    const QSettings rc(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/plasmanotifyrc"),
                       QSettings::IniFormat);
    m_trayDnd = dndUntilActive(rc.value(QStringLiteral("DoNotDisturb/Until")).toString(), QDateTime::currentDateTime());
    auto get = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.Notifications"), QStringLiteral("/org/freedesktop/Notifications"),
                                              QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"));
    get << QStringLiteral("org.freedesktop.Notifications") << QStringLiteral("Inhibited");
    callAsync(this, get, [this](const QDBusMessage &reply) {
        m_inhibited = !reply.arguments().isEmpty() && reply.arguments().first().value<QDBusVariant>().variant().toBool();
        m_dnd = silenced(m_dndCookie, m_trayDnd, m_inhibited, false);
        Q_EMIT changed();
    });
}

void SystemStatus::refreshEditMode()
{
    auto get = QDBusMessage::createMethodCall(QStringLiteral("org.kde.plasmashell"), QStringLiteral("/PlasmaShell"),
                                              QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"));
    get << QStringLiteral("org.kde.PlasmaShell") << QStringLiteral("editMode");
    callAsync(this, get, [this](const QDBusMessage &reply) {
        const bool on = !reply.arguments().isEmpty() && reply.arguments().first().value<QDBusVariant>().variant().toBool();
        if (on != m_editMode) {
            m_editMode = on;
            Q_EMIT changed();
        }
    });
}

void SystemStatus::readKeepAwake()
{
    auto has = QDBusMessage::createMethodCall(QStringLiteral("org.kde.Solid.PowerManagement"), QStringLiteral("/org/kde/Solid/PowerManagement/PolicyAgent"),
                                              QStringLiteral("org.kde.Solid.PowerManagement.PolicyAgent"), QStringLiteral("HasInhibition"));
    has << kChangeScreenSettings;
    callAsync(this, has, [this](const QDBusMessage &reply) {
        const bool held = !reply.arguments().isEmpty() && reply.arguments().first().toBool();
        m_keepAwake = m_awakeCookie || held;
        Q_EMIT changed();
    });
}

void SystemStatus::toggleMute()
{
    run(QStringLiteral("wpctl"), {QStringLiteral("set-mute"), kSink, QStringLiteral("toggle")}, [this](const QString &) { refresh(); });
}

void SystemStatus::changeVolume(int deltaPercent)
{
    const auto step = QStringLiteral("%1%%2").arg(qAbs(deltaPercent)).arg(deltaPercent >= 0 ? QLatin1Char('+') : QLatin1Char('-'));
    run(QStringLiteral("wpctl"), {QStringLiteral("set-volume"), QStringLiteral("-l"), QStringLiteral("1.0"), kSink, step}, [this, deltaPercent](const QString &) {
        // Down to 0 mutes (the keyboard's mute light follows); turning it up from muted unmutes.
        run(QStringLiteral("wpctl"), {QStringLiteral("get-volume"), kSink}, [this, deltaPercent](const QString &out) {
            const auto v = parseWpctlVolume(out);
            const bool mute = v && v->first == 0 && !v->second;
            const bool unmute = v && deltaPercent > 0 && v->second;
            if (mute || unmute)
                run(QStringLiteral("wpctl"), {QStringLiteral("set-mute"), kSink, mute ? QStringLiteral("1") : QStringLiteral("0")}, [this](const QString &) { refresh(); });
            else
                refresh();
        });
    });
}

void SystemStatus::setWifi(bool on)
{
    run(QStringLiteral("nmcli"), {QStringLiteral("radio"), QStringLiteral("wifi"), on ? QStringLiteral("on") : QStringLiteral("off")},
        [this](const QString &) { refresh(); });
}

void SystemStatus::setBluetooth(bool on)
{
    run(QStringLiteral("bluetoothctl"), {QStringLiteral("power"), on ? QStringLiteral("on") : QStringLiteral("off")},
        [this](const QString &) { refresh(); });
}

void SystemStatus::setDnd(bool on)
{
    if (on && !m_dndCookie) {
        m_dndCookie = callForCookie(notifyCall(QStringLiteral("Inhibit")) << QStringLiteral("dynamic-island") << QStringLiteral("Do not disturb")
                                                                       << QVariantMap());
    } else if (!on) {
        if (m_dndCookie) {
            QDBusConnection::sessionBus().send(notifyCall(QStringLiteral("UnInhibit")) << m_dndCookie);
            m_dndCookie = 0;
        }
        run(QStringLiteral("kwriteconfig6"),
            {QStringLiteral("--notify"), QStringLiteral("--file"), QStringLiteral("plasmanotifyrc"), QStringLiteral("--group"),
             QStringLiteral("DoNotDisturb"), QStringLiteral("--key"), QStringLiteral("Until"), QStringLiteral("--delete")},
            [this](const QString &) { readDnd(); });
    }
    readDnd();
}

void SystemStatus::setKeepAwake(bool on)
{
    if (on && !m_awakeCookie) {
        m_awakeCookie = callForCookie(screenSaverCall(QStringLiteral("Inhibit")) << QStringLiteral("dynamic-island") << QStringLiteral("Keep screen awake"));
    } else if (!on && m_awakeCookie) {
        QDBusConnection::sessionBus().send(screenSaverCall(QStringLiteral("UnInhibit")) << m_awakeCookie);
        m_awakeCookie = 0;
    }
    // The power daemon updates its inhibition list asynchronously.
    QTimer::singleShot(300, this, &SystemStatus::readKeepAwake);
}

void SystemStatus::screenshot()
{
    Q_EMIT aboutToScreenshot();
    QTimer::singleShot(300, this, [] { QProcess::startDetached(QStringLiteral("spectacle"), {}); });
}

void SystemStatus::pickColor()
{
    auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/ColorPicker"), QStringLiteral("org.kde.kwin.ColorPicker"),
                                              QStringLiteral("pick"));
    // Waits for the user's click, so no short timeout. A short delay lets the panel close first.
    QTimer::singleShot(300, this, [this, msg] {
        auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg, 5 * 60 * 1000), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher] {
            watcher->deleteLater();
            const QDBusMessage reply = watcher->reply();
            if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty())
                return;
            // Sent as a struct holding one ARGB number.
            const QDBusArgument arg = reply.arguments().first().value<QDBusArgument>();
            uint argb = 0;
            arg.beginStructure();
            arg >> argb;
            arg.endStructure();
            Q_EMIT colorPicked(QColor::fromRgba(argb).name());
        });
    });
}

void SystemStatus::lock()
{
    QProcess::startDetached(QStringLiteral("loginctl"), {QStringLiteral("lock-session")});
}
