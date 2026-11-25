#pragma once

#include <QObject>
#include <QRectF>
#include <QStringList>
#include <QWindow>
#include <qqmlintegration.h>

class InputRegion : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    using QObject::QObject;

    // On Qt Wayland, QWindow::setMask sets the surface input region, so clicks
    // outside the visible pill(s) fall through to the panel underneath.
    Q_INVOKABLE void set(QWindow *window, const QRectF &rect, const QRectF &extraRect = QRectF());
    // The mask for rect; an empty one becomes 1x1, since an empty mask lets the whole window take clicks.
    static QRect maskRect(const QRectF &rect);
    // Lets the layer-shell surface take keyboard focus when clicked (OnDemand), or never.
    // Exclusive takes it straight away, for the panel opened with the shortcut.
    Q_INVOKABLE void setKeyboard(QWindow *window, bool on, bool exclusive = false);
    // Overlay sits above full-screen windows; Top, the usual layer, sits below them.
    Q_INVOKABLE void setLayer(QWindow *window, bool overlay);
    // KWin blurs what's behind the island's rounded shape(s) (for the see-through look), or nothing.
    Q_INVOKABLE void setBlur(QWindow *window, const QRectF &rect, qreal radius, bool on,
                             const QRectF &extraRect = QRectF(), qreal extraRadius = 0);
    // The blur region: rect with rounded corners, as KWin takes it.
    static QRegion roundedRegion(const QRectF &rect, qreal radius);
    // Connected monitor names (e.g. "eDP-1", "DP-1") for the multi-monitor picker.
    Q_INVOKABLE QStringList screenNames() const;
    // Moves the layer-shell window to the named monitor (or primary when empty).
    Q_INVOKABLE void setScreen(QWindow *window, const QString &screenName);
};
