import MBProgressHUD
import Photos
import SPAlert
import SPPermissions
import UIKit

class CollectionListsViewController: UITableViewController {
    private var lists: PHFetchResult<PHCollectionList>?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.lists == nil {
            self.refresh()
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let controller = segue.destination as? CollectionsViewController {
            let list = self.lists!.object(at: self.tableView.indexPathForSelectedRow!.row)
            controller.list = list
        }
    }

    @IBAction
    func refresh(_: UIRefreshControl) {
        self.refresh()
    }

    private func refresh() {
        if refreshControl!.isRefreshing {
            refreshControl!.endRefreshing()
        }

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

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        self.lists = PHCollectionList.fetchCollectionLists(with: .folder, subtype: .regularFolder, options: options)
        self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
    }

    @IBAction
    func createFolder(_: UIBarButtonItem) {
        showEditor(title: "Create Album Collection", message: "Enter name for new collection.", placeholder: nil) { name in
            let hud = MBProgressHUD.showAdded(to: self.tabBarController!.view, animated: true)
            PHPhotoLibrary.shared().performChanges {
                guard let name = name else { return }
                PHCollectionListChangeRequest.creationRequestForCollectionList(withTitle: name)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    hud.hide(animated: true)
                    guard success, error == nil else {
                        SPAlert.present(title: "Creation Failed", message: error!.localizedDescription, preset: .error)
                        return
                    }

                    self.refresh()
                }
            }
        }
    }

    override func numberOfSections(in _: UITableView) -> Int {
        1
    }

    override func tableView(_: UITableView, titleForHeaderInSection _: Int) -> String? {
        "User-Created Album Collections"
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        self.lists?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "basic", for: indexPath)
        let collection = self.lists!.object(at: indexPath.row)
        cell.textLabel!.text = collection.localizedTitle
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "enumerateAlbums", sender: self)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension CollectionListsViewController: SPPermissionsDataSource, SPPermissionsDelegate {
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
