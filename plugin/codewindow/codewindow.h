#ifndef CODEWINDOW_H
#define CODEWINDOW_H

#include <QPointer>

#include "pluginapi.h"
#include "scplugin.h"

class QDockWidget;

class PLUGIN_API CodeWindowPlugin : public ScActionPlugin
{
	Q_OBJECT

public:
	CodeWindowPlugin();
	~CodeWindowPlugin() override = default;

	bool run(ScribusDoc* doc, const QString& target = QString()) override;
	bool handleSelection(ScribusDoc* doc, int selectedType = -1) override;
	QString fullTrName() const override;

	const AboutData* getAboutData() const override;
	void deleteAboutData(const AboutData* about) const override;

	void languageChange() override;
	void addToMainWindowMenu(ScribusMainWindow*) override {}

private:
	static QPointer<QDockWidget> s_dock;
};

extern "C" PLUGIN_API int codewindow_getPluginAPIVersion();
extern "C" PLUGIN_API ScPlugin* codewindow_getPlugin();
extern "C" PLUGIN_API void codewindow_freePlugin(ScPlugin* plugin);

#endif
