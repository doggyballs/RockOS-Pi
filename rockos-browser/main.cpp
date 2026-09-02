#include <QApplication>
#include <QWebEngineView>
#include <QUrl>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

    QWebEngineView view;

    view.load(QUrl::fromLocalFile(
        "/opt/rockos/app/entropylab.html"
    ));

    view.showFullScreen();

    return app.exec();
}
