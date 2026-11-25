#include "taskwatcher.h"

#include <QFile>
#include <QSet>

#include <dirent.h>
#include <unistd.h>

namespace
{
QString readSmallFile(const QString &path)
{
    QFile f(path);
    return f.open(QIODevice::ReadOnly) ? QString::fromUtf8(f.readAll()) : QString();
}

// Priority order: higher-level build/package drivers win over sub-tools (e.g. yay > makepkg > ninja).
struct ToolSpec {
    const char *comm;
    const char *label;
    int priority;
};

constexpr ToolSpec kTools[] = {
    {"yay", "yay", 10},
    {"paru", "paru", 10},
    {"pacman", "pacman", 9},
    {"makepkg", "makepkg", 8},
    {"flatpak", "flatpak", 8},
    {"cmake", "cmake", 7},
    {"meson", "meson", 7},
    {"cargo", "cargo", 7},
    {"ninja", "ninja", 6},
    {"make", "make", 6},
    {"gradle", "gradle", 6},
    {"mvn", "maven", 6},
    {"npm", "npm", 5},
    {"pnpm", "pnpm", 5},
    {"yarn", "yarn", 5},
    {"go", "go", 5},
    {"rsync", "rsync", 7},
    {"rclone", "rclone", 7},
    {"ffmpeg", "ffmpeg", 7},
    {"tar", "tar", 5},
    {"7z", "7z", 5},
    {"zstd", "zstd", 5},
    {"docker", "docker", 6},
    {"podman", "podman", 6},
};

const ToolSpec *matchTool(const QString &comm)
{
    for (const auto &t : kTools) {
        if (comm == QLatin1String(t.comm))
            return &t;
    }
    return nullptr;
}

QString readCmdDetail(const QString &pidDir, const QString &fallback)
{
    QFile f(pidDir + QStringLiteral("/cmdline"));
    if (!f.open(QIODevice::ReadOnly))
        return fallback;
    const QByteArray raw = f.read(512);
    if (raw.isEmpty())
        return fallback;
    const QList<QByteArray> parts = raw.split('\0');
    QStringList args;
    for (const QByteArray &p : parts) {
        if (p.isEmpty())
            continue;
        QString s = QString::fromUtf8(p);
        if (args.isEmpty()) {
            const int slash = s.lastIndexOf(QLatin1Char('/'));
            if (slash >= 0)
                s = s.mid(slash + 1);
        }
        args.append(s);
        if (args.size() >= 4)
            break;
    }
    return args.isEmpty() ? fallback : args.join(QLatin1Char(' '));
}

// Field 22 of /proc/<pid>/stat is starttime in clock ticks since boot.
qint64 readStartTicks(const QString &pidDir)
{
    const QString stat = readSmallFile(pidDir + QStringLiteral("/stat"));
    const int rparen = stat.lastIndexOf(QLatin1Char(')'));
    if (rparen < 0)
        return -1;
    const QStringList fields = stat.mid(rparen + 2).split(QLatin1Char(' '), Qt::SkipEmptyParts);
    // After ") ", index 0 is state (field 3), so field 22 is index 19.
    return fields.size() > 19 ? fields.at(19).toLongLong() : -1;
}
}

TaskWatcher::TaskWatcher(QObject *parent)
    : QObject(parent)
{
    m_timer.setInterval(2500);
    connect(&m_timer, &QTimer::timeout, this, &TaskWatcher::poll);
}

void TaskWatcher::setEnabled(bool on)
{
    if (on == enabled())
        return;
    if (on) {
        m_timer.start();
        poll();
    } else {
        m_timer.stop();
        m_tracked.clear();
        if (!m_tasks.isEmpty()) {
            m_tasks.clear();
            Q_EMIT tasksChanged();
        }
    }
    Q_EMIT enabledChanged();
}

void TaskWatcher::setMinSeconds(int seconds)
{
    const int clamped = qMax(0, seconds);
    if (m_minSeconds == clamped)
        return;
    m_minSeconds = clamped;
    Q_EMIT minSecondsChanged();
}

double TaskWatcher::systemUptime() const
{
    const QString up = readSmallFile(QStringLiteral("/proc/uptime"));
    const int space = up.indexOf(QLatin1Char(' '));
    return space > 0 ? up.left(space).toDouble() : 0.0;
}

void TaskWatcher::poll()
{
    // DYNAMIC_ISLAND_TASK="cmake --build build" lets you preview a live build task immediately.
    const QString fake = qEnvironmentVariable("DYNAMIC_ISLAND_TASK");
    if (!fake.isEmpty()) {
        const QString name = fake.section(QLatin1Char(' '), 0, 0);
        int elapsed = m_tracked.contains(-1) ? m_tracked[-1].elapsedSec + 2 : 12;
        m_tracked[-1] = {name, fake, elapsed};
        m_tasks = {QVariantMap{{QStringLiteral("pid"), -1}, {QStringLiteral("name"), name}, {QStringLiteral("detail"), fake}, {QStringLiteral("elapsedSec"), elapsed}}};
        Q_EMIT tasksChanged();
        return;
    }

    const double uptime = systemUptime();
    const long hz = sysconf(_SC_CLK_TCK);
    if (uptime <= 0.0 || hz <= 0)
        return;

    struct Found {
        int pid;
        QString name;
        QString detail;
        int elapsedSec;
        int priority;
    };
    QList<Found> active;
    QSet<int> seenPids;

    if (DIR *proc = opendir("/proc")) {
        while (const dirent *p = readdir(proc)) {
            if (p->d_name[0] < '0' || p->d_name[0] > '9')
                continue;
            const int pid = QByteArray(p->d_name).toInt();
            const QString pidDir = QStringLiteral("/proc/") + QLatin1String(p->d_name);
            const QString comm = readSmallFile(pidDir + QStringLiteral("/comm")).trimmed();
            const ToolSpec *spec = matchTool(comm);
            if (!spec)
                continue;
            const qint64 ticks = readStartTicks(pidDir);
            if (ticks < 0)
                continue;
            const int elapsed = qMax(0, int(uptime - double(ticks) / double(hz)));
            if (elapsed < m_minSeconds)
                continue;
            seenPids.insert(pid);
            const QString label = QString::fromLatin1(spec->label);
            const QString detail = m_tracked.contains(pid) ? m_tracked.value(pid).detail : readCmdDetail(pidDir, label);
            active.append({pid, label, detail, elapsed, spec->priority});
        }
        closedir(proc);
    }

    // Emit taskFinished for any tracked task whose PID disappeared.
    for (auto it = m_tracked.begin(); it != m_tracked.end();) {
        if (!seenPids.contains(it.key())) {
            const Tracked done = it.value();
            it = m_tracked.erase(it);
            Q_EMIT taskFinished(done.name, done.detail, done.elapsedSec);
        } else {
            ++it;
        }
    }

    // Highest priority first, then longest running.
    std::sort(active.begin(), active.end(), [](const Found &a, const Found &b) {
        return a.priority != b.priority ? a.priority > b.priority : a.elapsedSec > b.elapsedSec;
    });

    QVariantList next;
    QSet<QString> seenNames;
    for (const Found &f : active) {
        m_tracked[f.pid] = {f.name, f.detail, f.elapsedSec};
        // Avoid showing duplicate entries of the same tool (e.g. parallel sub-makes).
        if (seenNames.contains(f.name))
            continue;
        seenNames.insert(f.name);
        next.append(QVariantMap{
            {QStringLiteral("pid"), f.pid},
            {QStringLiteral("name"), f.name},
            {QStringLiteral("detail"), f.detail},
            {QStringLiteral("elapsedSec"), f.elapsedSec},
        });
    }

    if (next != m_tasks) {
        m_tasks = next;
        Q_EMIT tasksChanged();
    }
}
