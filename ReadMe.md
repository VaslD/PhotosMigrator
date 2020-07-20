# Photos Migrator for iOS

## Why

Syncing iPhones and iPads has always been a pain in the ass; syncing photos, even so. If you followed Apple’s iTunes (for Windows) or Finder (on macOS) guide to sync photos to your iOS device, you would be restricted to:

- **sync from only one computer and one Photo Library**: switching computers or libraries wipes previously synced photos;
- **read-only copies on iOS device**: editing synced photos requires creating more copies of the same photo, resulting in a polluted photo library on iPhone and iPad;
- **sync from only System Photo Library on macOS**: really not a friendly solution to anyone managing more than one library;
- **one-way sync from your computer to iOS device**: you’ll need to “download” your photos from iOS device to your computer another way, which is not what I would call “sync”;
- ...

**Photos Migrator** is an iOS utility that gives you more file-oriented control over Photos. In its simplest form, you will:

1. Create a new folder in *Files* app, under *On My iPhone/iPad* > *Photos Migrator*.
2. Copy or save images and videos into this folder from other apps, or from your computer using iTunes File Sharing.
3. Launch *Photos Migrator*, choose the new folder, and tap the *Import* icon.
4. After granting *Photos Migrator* necessary permissions to access *Photos*, a new album with the same name as the new folder will be created in Photos. You will find all saved images and videos inside.

Photos are imported as if they were taken using Camera. You can edit, delete, favorite, manage using albums, or do whatever you want with them as regular photos in good-old Camera Roll. No more ownership and read-only nightmares.

## How

Install [Xcode](https://apps.apple.com/us/app/xcode/id497799835), [CocoaPods](https://guides.cocoapods.org/using/getting-started.html), and optionally [SwiftFormat](https://github.com/nicklockwood/SwiftFormat/blob/0.44.17/README.md#how-do-i-install-it) if you wanted to contribute.

Open a *Terminal* to the project folder (or this cloned repository), and run `pod install` to restore dependent packages ("Pods"). Follow the instructions after package installation to open this project in Xcode.

Configure developer and code signing in **Photos Migrator** > *Targets* > **PhotosMigrator** > *Signing & Capabilities* > *Team*. Optionally change the bundle identifier if you wanted to make this your own app and manage it under your Apple developer account.

Build and deploy the app to your device.
