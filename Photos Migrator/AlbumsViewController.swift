import AcknowList
import SPAlert
import UIKit
import WhatsNewKit

class AlbumsViewController: UITableViewController {
    private let manager = FileManager.default

    private var folders: [URL] = []
    private var monitoringChanges = false

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = editButtonItem
        if let delegate = UIApplication.shared.delegate as? AppDelegate {
            delegate.observers.append(NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                                                             object: nil, queue: .main, using: { _ in
                                                                                 self.refresh()
                                                                             }))
        }
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
        cell.textLabel!.textColor = .label
        if isEditing, indexPath.row == self.folders.count {
            cell.textLabel!.text = "Create New Album"
            cell.textLabel!.font = UIFont.preferredFont(forTextStyle: .headline)
            cell.accessoryType = .none
        } else {
            do {
                cell.textLabel!.text = try self.folders[indexPath.row].resourceValues(forKeys: Set(arrayLiteral: .nameKey)).name!
                cell.textLabel!.font = UIFont.preferredFont(forTextStyle: .body)
                cell.accessoryType = .disclosureIndicator
            } catch {
                cell.textLabel!.text = "[Error] Folder no longer readable."
                cell.textLabel!.font = UIFont.preferredFont(forTextStyle: .body)
                cell.textLabel!.textColor = .systemRed
                cell.accessoryType = .none
            }
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
        self.performSegue(withIdentifier: "traverseFolder", sender: self)
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
                SPAlert.present(title: "Album Not Deleted", message: error.localizedDescription, preset: .error)
            }
        }
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
    }

    @IBAction
    func showAboutPage(_: UIBarButtonItem) {
        let about = WhatsNew(title: "Photos Migrator", items: [
            WhatsNew.Item(title: "Create Albums as Folders", subtitle: "Use Edit mode or Files app to create custom-named folders. These will be albums which contains imported photos.", image: UIImage(systemName: "folder.fill.badge.plus")),
            WhatsNew.Item(title: "Add Images", subtitle: "Use Files app, third-party apps, and iTunes to manage images inside albums (folders). Videos are not yet supported.", image: UIImage(systemName: "photo.fill")),
            WhatsNew.Item(title: "Browse Photos to Import", subtitle: "In Photos Migrator, browse albums and photos to be imported. Optionally, delete unwanted ones.", image: UIImage(systemName: "eye.fill")),
            WhatsNew.Item(title: "Migrate", subtitle: "In each album, tap the \"Import\" icon on upper-right to import this album.", image: UIImage(systemName: "tray.and.arrow.down.fill")),
        ])
        var config = WhatsNewViewController.Configuration()
        config.detailButton = WhatsNewViewController.DetailButton(title: "Acknowledgements", action: .custom(action: { _ in
            self.dismiss(animated: true, completion: {
                let acknowledgements = AcknowListViewController(fileNamed: "Acknowledgements")
                acknowledgements.headerText = "Photos Migrator by VaslD\nBuilt on open-source libraries."
                acknowledgements.footerText = "Icon made by Good Ware from Flaticon.\n\nSpecial thanks to CocoaPods and SwiftFormat."
                self.navigationController!.pushViewController(acknowledgements, animated: true)
            })
        }))
        config.completionButton = WhatsNewViewController.CompletionButton(title: "Done", action: .dismiss)
        let controller = WhatsNewViewController(whatsNew: about, configuration: config)
        controller.present(on: self, animated: true, completion: nil)
    }

    // MARK: I/O

    @IBAction
    func refresh(_: UIRefreshControl) {
        self.refresh()
    }

    private func refresh() {
        do {
            let root = try self.manager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            self.folders = try self.manager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.nameKey, .isDirectoryKey],
                                                                options: [.skipsHiddenFiles])
                .filter { item in (try? item.resourceValues(forKeys: Set(arrayLiteral: .isDirectoryKey)))?.isDirectory == true }

            if self.folders.isEmpty {
                SPAlert.present(title: "No Albums Found",
                                message: "You can create albums and add photos to import in Edit mode or using Files app.",
                                preset: .question)
            }
        } catch {
            SPAlert.present(title: "Unknown I/O Error", message: error.localizedDescription, preset: .error)
            self.folders = []
        }

        if self.refreshControl!.isRefreshing {
            self.refreshControl!.endRefreshing()
        }
        self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
    }

    private func createDirectory() {
        self.showEditor(title: "Create New Album", message: "Enter the name of new album.", placeholder: "Untitled",
                        actionHandler: { text in
                            guard let name = text else { return }
                            let root = try! self.manager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                            let url = root.appendingPathComponent(name, isDirectory: true)
                            do {
                                try self.manager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                                DispatchQueue.main.async { self.refresh() }
                            } catch {
                                SPAlert.present(title: "Cannot Create Album", message: error.localizedDescription, preset: .error)
                            }
                        })
    }
}
