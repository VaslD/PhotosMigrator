import UIKit

import SPAlert

class FoldersViewController: UITableViewController {
    let manager = FileManager.default

    var folders: [URL] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = editButtonItem
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.refresh()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let controller = segue.destination as? PhotosViewController {
            controller.path = self.folders[self.tableView.indexPathForSelectedRow!.row]
        }
    }

    override func numberOfSections(in _: UITableView) -> Int { 1 }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        let count = self.folders.count
        return self.isEditing ? count + 1 : count
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "basic", for: indexPath)
        if isEditing, indexPath.row == self.folders.count {
            cell.textLabel!.text = "Create New Folder"
            cell.textLabel!.font = UIFont.preferredFont(forTextStyle: .headline)
            cell.accessoryType = .none
        } else {
            cell.textLabel!.text = try! self.folders[indexPath.row].resourceValues(forKeys: Set(arrayLiteral: .nameKey)).name!
            cell.textLabel!.font = UIFont.preferredFont(forTextStyle: .body)
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            self.tableView.deselectRow(at: indexPath, animated: true)
        }

        if self.isEditing, indexPath.row == self.folders.count {
            self.createDirectory()
            return
        }

        guard !self.isEditing else { return }
        self.performSegue(withIdentifier: "traverse", sender: self)
    }

    override func tableView(_: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        guard self.isEditing else { return .none }

        if indexPath.row == self.folders.count { return .insert }
        else { return .delete }
    }

    override func tableView(_: UITableView, commit _: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if indexPath.row == self.folders.count {
            self.createDirectory()
        } else {
            do {
                try self.manager.removeItem(at: self.folders[indexPath.row])
                self.folders.remove(at: indexPath.row)
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
            } catch {
                SPAlert.present(title: "Folder Not Delete", message: error.localizedDescription, preset: .error)
            }
        }
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
    }

    // MARK: I/O

    @IBAction func refresh(_: UIRefreshControl, forEvent _: UIEvent) {
        self.refresh()
    }

    private func refresh() {
        do {
            let root = try self.manager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            self.folders = try self.manager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.nameKey, .isDirectoryKey],
                                                                options: [])
                .filter { item in (try? item.resourceValues(forKeys: Set(arrayLiteral: .isDirectoryKey)))?.isDirectory == true }

            if self.folders.isEmpty {
                SPAlert.present(title: "No Collection Found", message: "You can create collections and prepare photos to import in Edit mode or using Files app.", preset: .question)
            }
        } catch {
            SPAlert.present(title: "I/O Error", message: error.localizedDescription, preset: .error)
            self.folders = []
        }

        if self.refreshControl!.isRefreshing {
            self.refreshControl!.endRefreshing()
        }
        self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
    }

    private func createDirectory() {
        self.showEditor(title: "Create New Folder", message: "Enter the name of new folder.", placeholder: "Untitled",
                        actionHandler: { text in
                            guard let name = text else { return }
                            let root = try! self.manager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                            let url = root.appendingPathComponent(name, isDirectory: true)
                            do {
                                try self.manager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                                DispatchQueue.main.async { self.refresh() }
                            } catch {
                                SPAlert.present(title: "Cannot Create Folder", message: error.localizedDescription, preset: .error)
                            }
                        })
    }
}
