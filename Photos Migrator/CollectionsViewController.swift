import Photos
import UIKit

class CollectionsViewController: UITableViewController {
    var list: PHCollectionList!
    var collections: PHFetchResult<PHCollection>?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.refresh()
    }

    @IBAction
    func refresh(_: UIRefreshControl) {
        self.refresh()
    }

    private func refresh() {
        if refreshControl!.isRefreshing {
            refreshControl!.endRefreshing()
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        self.collections = PHAssetCollection.fetchCollections(in: self.list, options: options)
        self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let root = segue.destination as? UINavigationController,
            let controller = root.viewControllers[0] as? MoveAlbumsViewController
        {
            controller.parentFolder = self.list
        }
    }

    override func numberOfSections(in _: UITableView) -> Int {
        1
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        self.collections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "basic", for: indexPath)
        let collection = self.collections!.object(at: indexPath.row)
        cell.textLabel!.text = collection.localizedTitle
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_: UITableView, accessoryButtonTappedForRowWith _: IndexPath) {}
}
