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
        do {
            cell.textLabel!.text = try self.photos[indexPath.row].resourceValues(forKeys: Set(arrayLiteral: .nameKey)).name!
            cell.textLabel!.textColor = .label
        } catch {
            cell.textLabel!.text = "[Error] File no longer readable!"
            cell.textLabel!.textColor = .systemRed
        }
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

    @IBAction
    func refresh(_: UIRefreshControl) {
        self.refresh()
    }

    private func refresh() {
        do {
            self.photos = try self.manager.contentsOfDirectory(at: self.path!, includingPropertiesForKeys: [.nameKey, .isDirectoryKey],
                                                               options: [.skipsHiddenFiles])
                .filter { item in (try? item.resourceValues(forKeys: Set(arrayLiteral: .isDirectoryKey)))?.isDirectory != true }
                .sorted { lhs, rhs in
                    lhs.lastPathComponent < rhs.lastPathComponent
                }

            if self.photos.isEmpty {
                self.navigationItem.rightBarButtonItems![0].isEnabled = false
                self.navigationItem.rightBarButtonItems![2].isEnabled = false
            } else {
                self.navigationItem.rightBarButtonItems![1].isEnabled = false
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

    @IBAction
    func importPhotos(_: UIBarButtonItem) {
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

    @IBAction
    func archivePhotos(_: UIBarButtonItem) {
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

        self.archivePhotos()
    }

    private func importPhotos() {
        let alert = UIAlertController(title: "Import \(photos.count) Photos", message: "A photo album with the same name will be created if doesn’t exist. You cannot cancel the migration process once it starts.", preferredStyle: .alert)
        let go = UIAlertAction(title: "Continue", style: .default, handler: { _ in
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
                                            let photo = photoCreationRequest.placeholderForCreatedAsset
                                        {
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
                                            preset: .exclamation)
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
        })
        alert.addAction(go)
        alert.preferredAction = go
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func archivePhotos() {
        var hud = MBProgressHUD.showAdded(to: navigationController!.view, animated: true)
        DispatchQueue.global(qos: .background).async {
            let name = try! self.path!.resourceValues(forKeys: Set(arrayLiteral: .nameKey)).name!
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "title == %@", name)
            let searchResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options)
            self.collection = searchResult.firstObject

            DispatchQueue.main.async {
                hud.hide(animated: true)
                guard let collection = self.collection else {
                    SPAlert.present(title: "No Album Found", message: "A photo album with the same name must exist in your Photos library in order to migrate photos to files.", preset: .error)
                    return
                }

                let alert = UIAlertController(title: "Export On-Device Photos", message: "Photos in an album with the same name will be saved to Photos Migrator as files. You may then transfer these files out of your device.", preferredStyle: .alert)
                let go = UIAlertAction(title: "Continue", style: .default, handler: { _ in
                    hud = MBProgressHUD.showAdded(to: self.navigationController!.view, animated: true)

                    DispatchQueue.global(qos: .background).async {
                        let assets = PHAsset.fetchAssets(in: collection, options: nil)
                        DispatchQueue.main.async {
                            self.progress = Progress(totalUnitCount: Int64(assets.count))
                            self.progress!.completedUnitCount = 0
                            hud.progressObject = self.progress
                            hud.mode = .annularDeterminate
                        }

                        let manager = PHAssetResourceManager.default()
                        let options = PHAssetResourceRequestOptions()
                        options.isNetworkAccessAllowed = true
                        assets.enumerateObjects { asset, _, _ in
                            let resources = PHAssetResource.assetResources(for: asset)
                            for resource in resources {
                                if resource.type == .fullSizePhoto || resource.type == .fullSizeVideo ||
                                    resource.type == .photo || resource.type == .video
                                {
                                    let photoPath = self.path!.appendingPathComponent(resource.originalFilename, isDirectory: false)
                                    if self.manager.fileExists(atPath: photoPath.absoluteString) {
                                        break
                                    }
                                    manager.writeData(for: resource, toFile: photoPath, options: options, completionHandler: { error in
                                        guard error == nil else {
                                            do { try self.manager.removeItem(at: photoPath) }
                                            catch {}
                                            return
                                        }

                                        DispatchQueue.main.async {
                                            self.progress!.completedUnitCount += 1
                                        }
                                    })
                                    break
                                }
                            }
                        }

                        let library = PHPhotoLibrary.shared()
                        library.performChanges({
                            PHAssetChangeRequest.deleteAssets(assets)
                        }, completionHandler: { _, _ in
                            DispatchQueue.main.async {
                                hud.hide(animated: true)
                                self.refresh()
                                if self.progress!.completedUnitCount == self.progress!.totalUnitCount {
                                    SPAlert.present(title: "Photos Exported", preset: .done)
                                } else {
                                    let failed = self.progress!.totalUnitCount - self.progress!.completedUnitCount
                                    SPAlert.present(title: "Some Photos Exported", message: "\(failed) photos encountered errors.",
                                                    preset: .exclamation)
                                }
                            }
                        })
                    }
                })
                alert.addAction(go)
                alert.preferredAction = go
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
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
        SPAlert.present(title: "Access Granted", message: "Try performing the operation again.", preset: .done)
    }

    func didDenied(permission _: SPPermission) {
        SPAlert.present(title: "Photo Library Access Denied",
                        message: "You can re-configure privacy authorization for Photos Migrator in Settings app.",
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
