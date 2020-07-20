import MBProgressHUD
import Photos
import QuickLook
import SPAlert
import SPPermissions
import UIKit

class PhotosViewController: UITableViewController {
    let manager = FileManager.default

    var path: URL?

    var photos: [URL] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItems!.insert(editButtonItem, at: 0)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.path == nil {
            SPAlert.present(title: "Internal Error", preset: .error)
            navigationController!.popViewController(animated: true)
        } else {
            navigationItem.title = try! self.path!.resourceValues(forKeys: Set(arrayLiteral: .nameKey)).name!
            self.refresh()
        }
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

    override func tableView(_: UITableView,
                            editingStyleForRowAt _: IndexPath) -> UITableViewCell.EditingStyle { .delete }

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
                                                               options: [])
                .filter { item in (try? item.resourceValues(forKeys: Set(arrayLiteral: .isDirectoryKey)))?.isDirectory != true }

            if self.photos.isEmpty {
                SPAlert.present(title: "Collection Empty", preset: .question)
                navigationController!.popViewController(animated: true)
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
        let progress = Progress(totalUnitCount: Int64(photos.count))
        let hud = MBProgressHUD.showAdded(to: self.navigationController!.view, animated: true)
        hud.mode = .annularDeterminate
        hud.progressObject = progress

        DispatchQueue.global(qos: .background).async {
            var collection: PHAssetCollection?

            let name = try! self.path!.resourceValues(forKeys: Set(arrayLiteral: .nameKey)).name!
            let searchOptions = PHFetchOptions()
            searchOptions.predicate = NSPredicate(format: "title == %@", name)
            let searchResult = PHAssetCollection.fetchTopLevelUserCollections(with: searchOptions)
            if searchResult.count == 1, let assetCollection = searchResult.firstObject as? PHAssetCollection {
                collection = assetCollection
            }

            let library = PHPhotoLibrary.shared()
            do {
                if let album = collection {
                    try library.performChangesAndWait {
                        if let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) {
                            var assets: [PHObjectPlaceholder] = []
                            for url in self.photos {
                                if let photoCreationRequest = PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: url),
                                    let photo = photoCreationRequest.placeholderForCreatedAsset {
                                    assets.append(photo)
                                    progress.completedUnitCount += 1
                                }
                            }
                            albumChangeRequest.addAssets(assets as NSArray)
                        } else {
                            DispatchQueue.main.async {
                                hud.hide(animated: true)
                                SPAlert.present(title: "Cannot Modify Photo Album", preset: .error)
                            }
                        }
                    }
                } else {
                    try library.performChangesAndWait {
                        let albumCreateRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)

                        var assets: [PHObjectPlaceholder] = []
                        for url in self.photos {
                            if let photoCreationRequest = PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: url),
                                let photo = photoCreationRequest.placeholderForCreatedAsset {
                                assets.append(photo)
                                progress.completedUnitCount += 1
                            }
                        }
                        albumCreateRequest.addAssets(assets as NSArray)
                    }
                }

                DispatchQueue.main.async {
                    hud.mode = .indeterminate
                }

                try self.manager.removeItem(at: self.path!)
            } catch {
                DispatchQueue.main.async {
                    hud.hide(animated: true)
                    SPAlert.present(title: "Cannot Import Photos", message: error.localizedDescription, preset: .error)
                }
                return
            }

            self.photos = []
            DispatchQueue.main.async {
                hud.hide(animated: true)
                SPAlert.present(title: "Photos Imported", message: "An album with imported photos was also created.", preset: .done)
                self.navigationController?.popViewController(animated: true)
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
