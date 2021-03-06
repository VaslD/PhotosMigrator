import MBProgressHUD
import Photos
import SPAlert
import UIKit

class MoveAlbumsViewController: UITableViewController {
    var parentFolder: PHCollectionList!
    var collections: [PHCollection]?
    var selections: [Bool] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Add to " + (self.parentFolder.localizedTitle ?? "Collection")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.refresh()
    }

    private func refresh() {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "localIdentifier != %@", self.parentFolder.localIdentifier)
        options.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        let collections = PHAssetCollection.fetchTopLevelUserCollections(with: options)
        self.collections = collections.objects(at: IndexSet(0 ..< collections.count)).filter { (item) -> Bool in
            item is PHAssetCollection
        }
        self.selections = Array(repeating: false, count: self.collections!.count)
        self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
    }

    override func numberOfSections(in _: UITableView) -> Int {
        1
    }

    override func tableView(_: UITableView, titleForHeaderInSection _: Int) -> String? {
        "Top-Level Albums"
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        self.collections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "basic", for: indexPath)
        let collection = self.collections![indexPath.row]
        cell.textLabel!.text = collection.localizedTitle
        cell.accessoryType = self.selections[indexPath.row] ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.selections[indexPath.row] = !self.selections[indexPath.row]
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }

    @IBAction
    func cancelMove(_: UIBarButtonItem) {
        navigationController!.dismiss(animated: true, completion: nil)
    }

    @IBAction
    func moveAlbum(_: UIBarButtonItem) {
        let hud = MBProgressHUD.showAdded(to: navigationController!.view, animated: true)
        PHPhotoLibrary.shared().performChanges {
            guard let request = PHCollectionListChangeRequest(for: self.parentFolder) else {
                hud.hide(animated: true)
                SPAlert.present(title: "Add Albums Failed", message: "Unable to initiate changes.", preset: .error)
                return
            }
            for index in 0 ..< self.collections!.count {
                if self.selections[index] {
                    request.insertChildCollections([self.collections![index]] as NSArray, at: IndexSet(arrayLiteral: 0))
                }
            }
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                hud.hide(animated: true)
                guard success, error == nil else {
                    SPAlert.present(title: "Add Albums Failed", message: error!.localizedDescription, preset: .error)
                    return
                }

                self.navigationController!.dismiss(animated: true, completion: nil)
            }
        }
    }
}
