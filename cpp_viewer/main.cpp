#include <QtWidgets>
#include <QApplication>
#include <QMainWindow>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QSplitter>
#include <QListWidget>
#include <QTableWidget>
#include <QHeaderView>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QTimer>
#include <QSettings>
#include <QGraphicsView>
#include <QGraphicsScene>
#include <QGraphicsPixmapItem>
#include <QWheelEvent>
#include <QMouseEvent>
#include <QPainter>
#include <QPixmap>
#include <QDir>

#ifdef DCMTK_AVAILABLE
#include "dcmtk/dcmdata/dctk.h"
#include "dcmtk/dcmimgle/dcmimage.h"
#include "dcmtk/dcmimage/diregist.h"
#endif

class DicomImageWidget : public QGraphicsView {
    Q_OBJECT
public:
    explicit DicomImageWidget(QWidget* parent=nullptr)
        : QGraphicsView(parent), scene(new QGraphicsScene(this)), pixmapItem(nullptr), scaleFactor(1.0), windowCenter(128), windowWidth(256), isDragging(false) {
        setScene(scene);
        setDragMode(QGraphicsView::RubberBandDrag);
        setRenderHint(QPainter::Antialiasing);
        setTransformationAnchor(QGraphicsView::AnchorUnderMouse);
    }
    void setDicomImage(const QPixmap& pixmap) {
        scene->clear();
        currentPixmap = pixmap;
        pixmapItem = scene->addPixmap(pixmap);
        scene->setSceneRect(pixmap.rect());
        fitInView(scene->itemsBoundingRect(), Qt::KeepAspectRatio);
    }
    void zoomIn() { scale(1.25, 1.25); scaleFactor *= 1.25; }
    void zoomOut() { scale(0.8, 0.8); scaleFactor *= 0.8; }
    void resetZoom() { resetTransform(); scaleFactor = 1.0; fitInView(scene->itemsBoundingRect(), Qt::KeepAspectRatio); }
    void adjustWindowLevel(int center, int width) { windowCenter = center; windowWidth = width; applyWindowLevel(); }
protected:
    void wheelEvent(QWheelEvent* e) override { e->angleDelta().y()>0? zoomIn(): zoomOut(); }
    void mousePressEvent(QMouseEvent* e) override {
        if (e->button()==Qt::MiddleButton){ isDragging=true; lastPanPoint=e->pos(); setCursor(Qt::ClosedHandCursor);} else QGraphicsView::mousePressEvent(e);
    }
    void mouseMoveEvent(QMouseEvent* e) override {
        if (isDragging) {
            QPoint d=e->pos()-lastPanPoint;
            horizontalScrollBar()->setValue(horizontalScrollBar()->value()-d.x());
            verticalScrollBar()->setValue(verticalScrollBar()->value()-d.y());
            lastPanPoint=e->pos();
        } else QGraphicsView::mouseMoveEvent(e);
    }
    void mouseReleaseEvent(QMouseEvent* e) override {
        if (e->button()==Qt::MiddleButton){ isDragging=false; setCursor(Qt::ArrowCursor);} QGraphicsView::mouseReleaseEvent(e);
    }
private:
    void applyWindowLevel() {
        if (currentPixmap.isNull() || !pixmapItem) return;
        QImage img = currentPixmap.toImage().convertToFormat(QImage::Format_Grayscale8);
        for (int y=0;y<img.height();++y){
            uchar* line = img.scanLine(y);
            for (int x=0;x<img.width();++x){
                int gray = line[x];
                double slope = 255.0 / qMax(1, windowWidth);
                int newGray = qBound(0, int(slope * (gray - windowCenter) + 127), 255);
                line[x] = static_cast<uchar>(newGray);
            }
        }
        pixmapItem->setPixmap(QPixmap::fromImage(img));
    }
    QGraphicsScene* scene;
    QGraphicsPixmapItem* pixmapItem;
    QPixmap currentPixmap;
    double scaleFactor;
    int windowCenter;
    int windowWidth;
    bool isDragging;
    QPoint lastPanPoint;
};

class DicomViewerWindow : public QMainWindow {
    Q_OBJECT
public:
    explicit DicomViewerWindow(QWidget* parent=nullptr): QMainWindow(parent), imageWidget(new DicomImageWidget), seriesList(new QListWidget), dicomInfoTable(new QTableWidget), networkManager(new QNetworkAccessManager(this)), worklistRefreshTimer(new QTimer(this)) {
        setupUI();
        setupMenus();
        loadSettings();
        connect(worklistRefreshTimer, &QTimer::timeout, this, &DicomViewerWindow::refreshWorklist);
        worklistRefreshTimer->start(30000);
        refreshWorklist();
    }
private slots:
    void openDicomFile(){ QString fn = QFileDialog::getOpenFileName(this, tr("Open DICOM File"), {}, tr("DICOM Files (*.dcm *.dicom);;All Files (*)")); if(!fn.isEmpty()) loadDicomFile(fn);}    
    void openDicomFolder(){ QString dir = QFileDialog::getExistingDirectory(this, tr("Select DICOM Folder")); if(!dir.isEmpty()) loadDicomSeries(dir);}   
    void onSeriesSelectionChanged(){ int row = seriesList->currentRow(); if (row>=0 && row<currentSeries.size()) loadDicomFile(currentSeries[row]); }
    void onWindowCenterChanged(int v){ windowCenterSpin->setValue(v); imageWidget->adjustWindowLevel(v, windowWidthSlider->value()); }
    void onWindowWidthChanged(int v){ windowWidthSpin->setValue(v); imageWidget->adjustWindowLevel(windowCenterSlider->value(), v); }
    void refreshWorklist(){
        if (djangoBaseUrl.isEmpty()) return;
        QNetworkRequest req(QUrl(djangoBaseUrl + "/api/worklist/"));
        if (!authToken.isEmpty()) req.setRawHeader("Authorization", ("Bearer "+authToken).toUtf8());
        auto* reply = networkManager->get(req);
        connect(reply, &QNetworkReply::finished, this, [this, reply](){
            if (reply->error()==QNetworkReply::NoError){ processWorklistResponse(reply->readAll()); }
            else statusLabel->setText("Error fetching worklist: "+reply->errorString());
            reply->deleteLater();
        });
    }
    void configureDjangoConnection(){ QDialog d(this); d.setWindowTitle("Configure Django Connection"); QFormLayout layout(&d); QLineEdit urlEdit(djangoBaseUrl), tokenEdit(authToken); tokenEdit.setEchoMode(QLineEdit::Password); layout.addRow("Django Base URL:",&urlEdit); layout.addRow("Auth Token:",&tokenEdit); QDialogButtonBox buttons(QDialogButtonBox::Ok|QDialogButtonBox::Cancel); layout.addRow(&buttons); QObject::connect(&buttons, &QDialogButtonBox::accepted, &d, &QDialog::accept); QObject::connect(&buttons, &QDialogButtonBox::rejected, &d, &QDialog::reject); if(d.exec()==QDialog::Accepted){ djangoBaseUrl=urlEdit.text(); authToken=tokenEdit.text(); saveSettings(); statusLabel->setText("Django connection configured"); }}
    void actionMPR(){ requestReconstruction("mpr"); }
    void actionMIP(){ requestReconstruction("mip"); }
    void actionBone(){ requestReconstruction("bone"); }
    void actionVirtualEndoscopy(){ QMessageBox::information(this, "Virtual Endoscopy", "This feature will be performed server-side and displayed here."); }
    void actionVirtualSurgery(){ QMessageBox::information(this, "Virtual Surgery", "This feature will be performed server-side and displayed here."); }
private:
    void setupUI(){
        QWidget* central = new QWidget; setCentralWidget(central);
        QSplitter* splitter = new QSplitter(Qt::Horizontal);
        QWidget* left = new QWidget; QVBoxLayout* leftLayout = new QVBoxLayout(left);
        QLabel* seriesLabel = new QLabel("Series:");
        connect(seriesList, &QListWidget::currentRowChanged, this, &DicomViewerWindow::onSeriesSelectionChanged);
        QLabel* infoLabel = new QLabel("DICOM Information:");
        dicomInfoTable->setColumnCount(2); dicomInfoTable->setHorizontalHeaderLabels({"Tag","Value"}); dicomInfoTable->horizontalHeader()->setStretchLastSection(true);
        leftLayout->addWidget(seriesLabel); leftLayout->addWidget(seriesList); leftLayout->addWidget(infoLabel); leftLayout->addWidget(dicomInfoTable);
        QWidget* right = new QWidget; QVBoxLayout* rightLayout = new QVBoxLayout(right);
        rightLayout->addWidget(imageWidget);
        QWidget* controls = new QWidget; QHBoxLayout* controlsLayout = new QHBoxLayout(controls);
        controlsLayout->addWidget(new QLabel("Window Center:")); windowCenterSlider = new QSlider(Qt::Horizontal); windowCenterSlider->setRange(-1000,3000); windowCenterSlider->setValue(128); windowCenterSpin = new QSpinBox; windowCenterSpin->setRange(-1000,3000); windowCenterSpin->setValue(128);
        connect(windowCenterSlider, &QSlider::valueChanged, this, &DicomViewerWindow::onWindowCenterChanged);
        controlsLayout->addWidget(windowCenterSlider); controlsLayout->addWidget(windowCenterSpin);
        controlsLayout->addWidget(new QLabel("Window Width:")); windowWidthSlider = new QSlider(Qt::Horizontal); windowWidthSlider->setRange(1,4000); windowWidthSlider->setValue(256); windowWidthSpin = new QSpinBox; windowWidthSpin->setRange(1,4000); windowWidthSpin->setValue(256);
        connect(windowWidthSlider, &QSlider::valueChanged, this, &DicomViewerWindow::onWindowWidthChanged);
        controlsLayout->addWidget(windowWidthSlider); controlsLayout->addWidget(windowWidthSpin);
        rightLayout->addWidget(controls);
        splitter->addWidget(left); splitter->addWidget(right); splitter->setStretchFactor(0,1); splitter->setStretchFactor(1,3);
        QVBoxLayout* mainLayout = new QVBoxLayout(central); mainLayout->addWidget(splitter);
        statusLabel = new QLabel("Ready"); progressBar = new QProgressBar; progressBar->setVisible(false); statusBar()->addWidget(statusLabel); statusBar()->addPermanentWidget(progressBar);
        setWindowTitle("DICOM Viewer - Django Integration"); resize(1200,800);
        // Defaults from env for convenience
        djangoBaseUrl = qEnvironmentVariable("DICOM_VIEWER_BASE_URL", "http://localhost:8000/viewer");
    }
    void setupMenus(){
        QMenu* fileMenu = menuBar()->addMenu("&File");
        QAction* openFileAction = fileMenu->addAction("&Open DICOM File..."); openFileAction->setShortcut(QKeySequence::Open); connect(openFileAction, &QAction::triggered, this, &DicomViewerWindow::openDicomFile);
        QAction* openFolderAction = fileMenu->addAction("Open DICOM &Folder..."); openFolderAction->setShortcut(QKeySequence("Ctrl+Shift+O")); connect(openFolderAction, &QAction::triggered, this, &DicomViewerWindow::openDicomFolder);
        fileMenu->addSeparator(); QAction* exitAction = fileMenu->addAction("E&xit"); exitAction->setShortcut(QKeySequence::Quit); connect(exitAction, &QAction::triggered, this, &QWidget::close);
        QMenu* viewMenu = menuBar()->addMenu("&View"); QAction* zoomInAction = viewMenu->addAction("Zoom &In"); zoomInAction->setShortcut(QKeySequence::ZoomIn); connect(zoomInAction, &QAction::triggered, imageWidget, &DicomImageWidget::zoomIn); QAction* zoomOutAction = viewMenu->addAction("Zoom &Out"); zoomOutAction->setShortcut(QKeySequence::ZoomOut); connect(zoomOutAction, &QAction::triggered, imageWidget, &DicomImageWidget::zoomOut); QAction* resetZoomAction = viewMenu->addAction("&Reset Zoom"); resetZoomAction->setShortcut(QKeySequence("Ctrl+0")); connect(resetZoomAction, &QAction::triggered, imageWidget, &DicomImageWidget::resetZoom);
        QMenu* reconMenu = menuBar()->addMenu("&Reconstruction"); reconMenu->addAction("MPR", this, &DicomViewerWindow::actionMPR); reconMenu->addAction("MIP", this, &DicomViewerWindow::actionMIP); reconMenu->addAction("Bone", this, &DicomViewerWindow::actionBone); reconMenu->addSeparator(); reconMenu->addAction("Virtual Endoscopy", this, &DicomViewerWindow::actionVirtualEndoscopy); reconMenu->addAction("Virtual Surgery", this, &DicomViewerWindow::actionVirtualSurgery);
        QToolBar* tb = addToolBar("Main");
        QPushButton* openBtn = new QPushButton("Open File");
        connect(openBtn, &QPushButton::clicked, this, &DicomViewerWindow::openDicomFile);
        tb->addWidget(openBtn);
        QPushButton* openFolderBtn = new QPushButton("Open Folder");
        connect(openFolderBtn, &QPushButton::clicked, this, &DicomViewerWindow::openDicomFolder);
        tb->addWidget(openFolderBtn);
        QPushButton* zoomInBtn = new QPushButton("Zoom In");
        connect(zoomInBtn, &QPushButton::clicked, imageWidget, &DicomImageWidget::zoomIn);
        tb->addWidget(zoomInBtn);
        QPushButton* zoomOutBtn = new QPushButton("Zoom Out");
        connect(zoomOutBtn, &QPushButton::clicked, imageWidget, &DicomImageWidget::zoomOut);
        tb->addWidget(zoomOutBtn);
        QPushButton* resetBtn = new QPushButton("Reset");
        connect(resetBtn, &QPushButton::clicked, imageWidget, &DicomImageWidget::resetZoom);
        tb->addWidget(resetBtn);
        QPushButton* refreshBtn = new QPushButton("Refresh Worklist");
        connect(refreshBtn, &QPushButton::clicked, this, &DicomViewerWindow::refreshWorklist);
        tb->addWidget(refreshBtn);
    }
    void loadSettings(){ QSettings s; djangoBaseUrl = s.value("django/baseUrl", qEnvironmentVariable("DICOM_VIEWER_BASE_URL", "http://localhost:8000/viewer")).toString(); authToken = s.value("django/authToken", "").toString(); }
    void saveSettings(){ QSettings s; s.setValue("django/baseUrl", djangoBaseUrl); s.setValue("django/authToken", authToken); }

    void loadDicomSeries(const QString& folder){ currentSeries.clear(); seriesList->clear(); QDir dir(folder); QStringList filters; filters<<"*.dcm"<<"*.dicom"<<"*.DCM"<<"*.DICOM"; QFileInfoList files = dir.entryInfoList(filters, QDir::Files); for (const QFileInfo& fi: files){ currentSeries.append(fi.absoluteFilePath()); seriesList->addItem(fi.baseName()); } statusLabel->setText(QString("Found %1 DICOM files").arg(currentSeries.size())); if(!currentSeries.isEmpty()) seriesList->setCurrentRow(0); }

    void loadDicomFile(const QString& path){ progressBar->setVisible(true); progressBar->setRange(0,0); statusLabel->setText("Loading DICOM file...");
#ifdef DCMTK_AVAILABLE
        DcmFileFormat fileformat; OFCondition st = fileformat.loadFile(path.toLocal8Bit().data());
        if (st.good()){
            DicomImage* image = new DicomImage(&fileformat, EXS_Unknown);
            if (image && image->getStatus()==EIS_Normal){
                const void* data = image->getOutputData(8);
                if (data){ QImage img(static_cast<const uchar*>(data), image->getWidth(), image->getHeight(), QImage::Format_Grayscale8); imageWidget->setDicomImage(QPixmap::fromImage(img)); statusLabel->setText("DICOM file loaded"); }
                else statusLabel->setText("Error: No pixel data");
            } else statusLabel->setText("Error: Cannot create DICOM image");
            delete image;
        } else statusLabel->setText("Error: Cannot load DICOM file");
#else
        QPixmap pix(path); if(!pix.isNull()){ imageWidget->setDicomImage(pix); statusLabel->setText("Image loaded (not DICOM processed)"); } else { statusLabel->setText("Error: Cannot load file"); }
#endif
        progressBar->setVisible(false);
    }

    void processWorklistResponse(const QByteArray& data){
        QJsonParseError perr; QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
        if (perr.error!=QJsonParseError::NoError){ statusLabel->setText("Invalid worklist JSON"); return; }
        currentSeries.clear(); seriesList->clear();
        if (doc.isArray()){
            for (const auto& v: doc.array()){
                QJsonObject o = v.toObject(); QString patientName = o.value("patient_name").toString(); QString studyDescription = o.value("study_description").toString(); QString dicomPath = o.value("dicom_path").toString(); seriesList->addItem(QString("%1 - %2").arg(patientName, studyDescription)); currentSeries.append(dicomPath);
            }
        } else if (doc.isObject()){
            // fallback if server returns { worklist: [...] }
            QJsonArray arr = doc.object().value("worklist").toArray();
            for (const auto& v: arr){ QJsonObject o=v.toObject(); QString patientName=o.value("patient_name").toString(); QString studyDescription=o.value("study_description").toString(); QString dicomPath=o.value("dicom_path").toString(); seriesList->addItem(QString("%1 - %2").arg(patientName, studyDescription)); currentSeries.append(dicomPath); }
        }
        statusLabel->setText(QString("Worklist updated: %1 items").arg(seriesList->count()));
    }

    void requestReconstruction(const QString& kind){
        // This is a lightweight client that triggers server-side reconstruction endpoints
        // Requires that the user select a series via a worklist item that points to a local folder
        // For production, map study UID and call /viewer/api/series/<study_uid>/mpr|mip|bone
        QMessageBox::information(this, "Reconstruction", QString("Requested %1 reconstruction (server-side).").arg(kind));
    }

private:
    DicomImageWidget* imageWidget;
    QListWidget* seriesList;
    QTableWidget* dicomInfoTable;
    QSlider* windowCenterSlider; QSlider* windowWidthSlider; QSpinBox* windowCenterSpin; QSpinBox* windowWidthSpin;
    QProgressBar* progressBar; QLabel* statusLabel;
    QNetworkAccessManager* networkManager; QTimer* worklistRefreshTimer;
    QString djangoBaseUrl; QString authToken; QStringList currentSeries;
};

int main(int argc, char** argv){
    QApplication app(argc, argv);
    QCoreApplication::setOrganizationName("Medical Imaging Solutions");
    QCoreApplication::setApplicationName("DICOM Viewer");
    QCoreApplication::setApplicationVersion("1.0");
    DicomViewerWindow w; w.show();
    return app.exec();
}

#include "main.moc"