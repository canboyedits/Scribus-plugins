#include "codewindow.h"

#include <QDockWidget>
#include <QLabel>
#include <QMessageBox>
#include <QPlainTextEdit>
#include <QPushButton>
#include <QVBoxLayout>
#include <QWidget>

#include "commonstrings.h"
#include "pageitem.h"
#include "scpage.h"
#include "scribus.h"
#include "scribuscore.h"
#include "scribusdoc.h"
#include "scribusview.h"
#include "text/specialchars.h"

QPointer<QDockWidget> CodeWindowPlugin::s_dock = nullptr;

int codewindow_getPluginAPIVersion()
{
	return PLUGIN_API_VERSION;
}

ScPlugin* codewindow_getPlugin()
{
	CodeWindowPlugin* plugin = new CodeWindowPlugin();
	Q_CHECK_PTR(plugin);
	return plugin;
}

void codewindow_freePlugin(ScPlugin* plugin)
{
	CodeWindowPlugin* codePlugin = qobject_cast<CodeWindowPlugin*>(plugin);
	Q_ASSERT(codePlugin);
	delete codePlugin;
}

CodeWindowPlugin::CodeWindowPlugin()
{
	languageChange();
}

void CodeWindowPlugin::languageChange()
{
	m_actionInfo.name = "CodeWindow";
	m_actionInfo.text = tr("Code Window...");
	m_actionInfo.menu = "Extras";
	m_actionInfo.enabledOnStartup = true;

	// This plugin does not require any selected object.
	// Without this, Scribus may disable the menu item after a document opens.
	m_actionInfo.needsNumObjects = -1;
}

bool CodeWindowPlugin::handleSelection(ScribusDoc*, int)
{
	// Keep the menu action enabled regardless of current selection.
	// The Paste button itself checks whether a document/page exists.
	return true;
}

QString CodeWindowPlugin::fullTrName() const
{
	return QObject::tr("Code Window");
}

const ScActionPlugin::AboutData* CodeWindowPlugin::getAboutData() const
{
	AboutData* about = new AboutData;
	Q_CHECK_PTR(about);

	about->authors = QString::fromUtf8("Yash");
	about->shortDescription = tr("Floating paste window for Scribus.");
	about->description = tr("Opens a floating window and inserts pre-entered text into a new text frame on the current page.");
	about->license = "GPL";

	return about;
}

void CodeWindowPlugin::deleteAboutData(const AboutData* about) const
{
	Q_ASSERT(about);
	delete about;
}

bool CodeWindowPlugin::run(ScribusDoc*, const QString&)
{
	ScribusMainWindow* mainWindow = ScCore ? ScCore->primaryMainWindow() : nullptr;
	if (mainWindow == nullptr)
		return true;

	if (!s_dock.isNull())
	{
		s_dock->show();
		s_dock->raise();
		s_dock->activateWindow();
		return true;
	}

	auto* panel = new QWidget();
	auto* layout = new QVBoxLayout(panel);

	auto* label = new QLabel(
		tr("Click Paste to create a text frame on the current page and fill it with this text."),
		panel
	);
	label->setWordWrap(true);

	auto* editor = new QPlainTextEdit(panel);
	editor->setPlainText(
		"Hello from Code Window plugin!\n\n"
		"This text was inserted by a Scribus C++ plugin.\n"
		"You can replace this pre-entered text later."
	);

	auto* pasteButton = new QPushButton(tr("Paste"), panel);

	layout->addWidget(label);
	layout->addWidget(editor, 1);
	layout->addWidget(pasteButton);

	auto* dock = new QDockWidget(tr("Code Window"), mainWindow);
	dock->setObjectName("CodeWindowDock");
	dock->setWidget(panel);
	dock->setAllowedAreas(Qt::AllDockWidgetAreas);
	dock->setFeatures(
		QDockWidget::DockWidgetClosable |
		QDockWidget::DockWidgetMovable |
		QDockWidget::DockWidgetFloatable
	);

	mainWindow->addDockWidget(Qt::RightDockWidgetArea, dock);
	dock->setFloating(true);
	dock->resize(520, 360);
	dock->show();

	s_dock = dock;

	QObject::connect(dock, &QObject::destroyed, []() {
		CodeWindowPlugin::s_dock = nullptr;
	});

	QObject::connect(pasteButton, &QPushButton::clicked, [editor, dock]() {
		ScribusMainWindow* mw = ScCore ? ScCore->primaryMainWindow() : nullptr;
		ScribusDoc* doc = mw ? mw->doc : nullptr;

		if (doc == nullptr || doc->Pages == nullptr || doc->Pages->isEmpty())
		{
			QMessageBox::warning(dock, QObject::tr("Code Window"), QObject::tr("Open or create a Scribus document first."));
			return;
		}

		ScPage* page = doc->currentPage();
		if (page == nullptr)
		{
			QMessageBox::warning(dock, QObject::tr("Code Window"), QObject::tr("No current page is available."));
			return;
		}

		QString text = editor->toPlainText();
		if (text.trimmed().isEmpty())
		{
			QMessageBox::warning(dock, QObject::tr("Code Window"), QObject::tr("There is no text to paste."));
			return;
		}

		text.replace("\r\n", SpecialChars::PARSEP);
		text.replace(QChar('\n'), SpecialChars::PARSEP);

		const double x = page->xOffset() + page->Margins.left();
		const double y = page->yOffset() + page->Margins.top();
		const double width = 260.0;
		const double height = 110.0;

		const int itemIndex = doc->itemAdd(
			PageItem::TextFrame,
			PageItem::Unspecified,
			x,
			y,
			width,
			height,
			0.0,
			CommonStrings::None,
			CommonStrings::None
		);

		if (itemIndex < 0 || itemIndex >= doc->Items->count())
		{
			QMessageBox::critical(dock, QObject::tr("Code Window"), QObject::tr("Could not create the text frame."));
			return;
		}

		PageItem* item = doc->Items->at(itemIndex);
		item->itemText.clear();
		item->itemText.insertChars(0, text);
		item->invalidateLayout();
		item->layout();

		doc->changed();
		if (doc->view() != nullptr)
			doc->view()->DrawNew();
	});

	return true;
}
