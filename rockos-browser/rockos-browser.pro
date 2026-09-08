QT += widgets webenginewidgets
CONFIG += c++11
CONFIG -= app_bundle

TARGET = rockos-browser
SOURCES += main.cpp

target.path = /usr/bin
INSTALLS += target
