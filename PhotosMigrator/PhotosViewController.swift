import MBProgressHUD
import Photos
import QuickLook
import SPAlert
import SPPermissions
import UIKit

class PhotosViewController: UITableViewController {
    let manager = FileManager.default

    var observer: NSObjectProtocol?

    var path: URL?
    var photos: [URL] = []
    var collection: PHAssetCollection?
    var progress: Progress?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItems!.insert(editButtonItem, at: 0)
        self.observer = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil,
                                                               queue: .main, using: { _ in
                                                                   self.refresh()
                                                               })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.path == nil {
            SPAlert.present(title: "Internal Error", preset: .error)
            self.dismiss()
        } else {
            self.navigationItem.title = try! self.path!.resourceValues(forKeys: Set(arrayLiteral: .nameKey)).name!
            self.refresh()
        }
    }

    func dismiss() {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
        self.navigationController!.popViewController(animated: true)
    }

    override func numberOfSections(in _: UITableView) -> Int { 1 }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int { self.photos.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "basic", for: indexPath)
        cell.textLabel!.text = try! self.photos[indexPath.row].resourceValues(forKeys: Set(arrayLiteral: .nameKey)).name!
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }

        let preview = QLPreviewController()
        preview.dataSource = self
        preview.delegate = self
        preview.currentPreviewItemIndex = indexPath.row
        present(preview, animated: true, completion: nil)
    }

    override func tableView(_: UITableView, editingStyleForRowAt _: IndexPath) -> UITableViewCell.EditingStyle { .delete }

    override func tableView(_: UITableView, commit _: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        do {
            try self.manager.removeItem(at: self.photos[indexPath.row])
            self.photos.remove(at: indexPath.row)
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
        } catch {
            SPAlert.present(title: "Photo Not Delete", message: error.localizedDescription, preset: .error)
        }
    }

    // MARK: I/O

    @IBAction func refresh(_: UIRefreshControl, forEvent _: UIEvent) {
        self.refresh()
    }

    private func refresh() {
        do {
            self.photos = try self.manager.contentsOfDirectory(at: self.path!, includingPropertiesForKeys: [.nameKey, .isDirectoryKey],
                                                               options: [.skipsHiddenFiles])
                .filter { item in (try? item.resourceValues(forKeys: Set(arrayLiteral: .isDirectoryKey)))?.isDirectory != true }

            if self.photos.isEmpty {
                SPAlert.present(title: "Album Empty", preset: .question)
                self.dismiss()
            }
        } catch {
            SPAlert.present(title: "I/O Error", message: error.localizedDescription, preset: .error)
            self.photos = []
        }

        if self.refreshControl!.isRefreshing {
            self.refreshControl!.endRefreshing()
        }
        self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
    }

    @IBAction func importPhotos(_: UIBarButtonItem) {
        guard PHPhotoLibrary.authorizationStatus() == .authorized else {
            let prompt = SPPermissions.dialog([.photoLibrary])
            prompt.titleText = "Permission Required"
            prompt.headerText = ""
            prompt.footerText = ""
            prompt.dataSource = self
            prompt.delegate = self
            prompt.present(on: self)
            return
        }

        self.importPhotos()
    }

    func importPhotos() {
        let hud = MBProgressHUD.showAdded(to: self.navigationController!.view, animated: true)
        hud.mode = .indeterminate

        DispatchQueue.global(qos: .background).async {
            let name = try! self.path!.resourceValues(forKeys: Set(arrayLiteral: .nameKey)).name!

            let library = PHPhotoLibrary.shared()

            let searchResults = PHAssetCollection.fetchTopLevelUserCollections(with: nil)
            searchResults.enumerateObjects { collection, _, shouldStop in
                if let result = collection as? PHAssetCollection, result.localizedTitle == name {
                    self.collection = result
                    shouldStop.pointee = true
                }
            }

            do {
                var id = ""
                if self.collection == nil {
                    try library.performChangesAndWait {
                        id = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                            .placeholderForCreatedAssetCollection.localIdentifier
                    }

                    let searchResults = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil)
                    searchResults.enumerateObjects { collection, _, shouldStop in
                        if collection.localIdentifier == id {
                            self.collection = collection
                            shouldStop.pointee = true
                        }
                    }
                }

                if let album = self.collection {
                    DispatchQueue.main.async {
                        self.progress = Progress(totalUnitCount: Int64(self.photos.count))
                        self.progress!.completedUnitCount = 0
                        hud.progressObject = self.progress
                        hud.mode = .annularDeterminate
                    }

                    var index = 0
                    while self.photos.count > index {
                        let url = self.photos[index]
                        do {
                            try library.performChangesAndWait {
                                if let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) {
                                    if let photoCreationRequest = PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: url),
                                        let photo = photoCreationRequest.placeholderForCreatedAsset {
                                        albumChangeRequest.addAssets([photo] as NSArray)
                                    }
                                }
                            }

                            try self.manager.removeItem(at: url)
                            self.photos.remove(at: index)

                            DispatchQueue.main.async {
                                self.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                                self.progress!.completedUnitCount += 1
                            }
                        } catch {
                            index += 1
                        }
                    }
                } else {
                    self.progress = nil
                    DispatchQueue.main.async {
                        hud.hide(animated: true)
                        SPAlert.present(title: "Cannot Import Photos", message: "Creation of photo album failed.", preset: .error)
                    }
                    return
                }

                DispatchQueue.main.async {
                    hud.hide(animated: true)
                    self.progress = nil
                    if self.photos.isEmpty {
                        SPAlert.present(title: "Photos Imported", message: "An album with imported photos was also created.",
                                        preset: .done)
                        self.dismiss()
                    } else {
                        SPAlert.present(title: "Some Photos Imported",
                                        message: "\(self.photos.count) not processed due to unknown errors.",
                                        preset: .done)
                    }
                }
            } catch {
                self.progress = nil
                DispatchQueue.main.async {
                    hud.hide(animated: true)
                    SPAlert.present(title: "Cannot Import Photos", message: error.localizedDescription, preset: .error)
                }
            }
        }
    }
}

extension PhotosViewController: QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    func numberOfPreviewItems(in _: QLPreviewController) -> Int { self.photos.count }

    func previewController(_: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { self.photos[index] as NSURL }
}

extension PhotosViewController: SPPermissionsDataSource, SPPermissionsDelegate {
    func configure(_ cell: SPPermissionTableViewCell, for permission: SPPermission) -> SPPermissionTableViewCell {
        if permission == .photoLibrary {
            cell.permissionTitleLabel.text = "Photo Library"
            cell.permissionDescriptionLabel.text = "Manage collections and albums. Add, delete, or modify photos."
            cell.button.allowTitle = "Grant"
            cell.button.allowedTitle = "Granted"
        }
        return cell
    }

    func didAllow(permission _: SPPermission) {
        self.importPhotos()
    }

    func didDenied(permission _: SPPermission) {
        SPAlert.present(title: "Photo Library Access Denied",
                        message: "You can re-configure privacy authorizations for Photos Migrator in Settings app.",
                        preset: .privacy)
    }

    func didHide(permissions ids: [Int]) {
        if ids.contains(SPPermission.photoLibrary.rawValue) {
            if PHPhotoLibrary.authorizationStatus() != .authorized {
                SPAlert.present(title: "Operation Cancelled", preset: .exclamation)
            }
        }
    }

    func deniedData(for _: SPPermission) -> SPPermissionDeniedAlertData? { nil }
}
