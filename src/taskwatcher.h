#pragma once

#include <QHash>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <qqmlintegration.h>

// Watches /proc for long-running build, package, and sync commands (cmake, ninja, yay, cargo, rsync, …)
// that have been running for at least minSeconds. Emits taskFinished when a tracked task ends.
class TaskWatcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    // Minimum runtime in seconds before a command appears in the island (ignores quick commands).
    Q_PROPERTY(int minSeconds READ minSeconds WRITE setMinSeconds NOTIFY minSecondsChanged)
    // Active long-running tasks: [{ pid, name, detail, elapsedSec }].
    Q_PROPERTY(QVariantList tasks READ tasks NOTIFY tasksChanged)

public:
    explicit TaskWatcher(QObject *parent = nullptr);

    bool enabled() const { return m_timer.isActive(); }
    void setEnabled(bool on);
    int minSeconds() const { return m_minSeconds; }
    void setMinSeconds(int seconds);
    QVariantList tasks() const { return m_tasks; }

Q_SIGNALS:
    void enabledChanged();
    void minSecondsChanged();
    void tasksChanged();
    void taskFinished(const QString &name, const QString &detail, int elapsedSec);

private:
    void poll();
    double systemUptime() const;

    struct Tracked {
        QString name;
        QString detail;
        int elapsedSec = 0;
    };

    QTimer m_timer;
    int m_minSeconds = 5;
    QVariantList m_tasks;
    QHash<int, Tracked> m_tracked;
};
