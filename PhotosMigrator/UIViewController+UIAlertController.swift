import Foundation
import UIKit

typealias UIAlertHandler = () -> Void
typealias UIAlertEditorHandler = (String?) -> Void

extension UIViewController {
    func showAlert(title: String, message: String?, action: String = "OK",
                   completionHandler: UIAlertHandler? = nil, actionHandler: UIAlertHandler? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: action, style: .default,
                                   handler: actionHandler == nil ? nil : { _ in
                                       actionHandler!()
                                   })
        alert.addAction(action)
        if #available(iOS 9.0, tvOS 9.0, macCatalyst 13.0, *) {
            alert.preferredAction = action
        }
        self.present(alert, animated: true, completion: completionHandler)
    }

    func showEditor(title: String, message: String?, placeholder: String?,
                    cancelAction: String = "Cancel", doneAction: String = "Done",
                    completionHandler: UIAlertHandler? = nil, actionHandler: UIAlertEditorHandler?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField(configurationHandler: { field in
            field.placeholder = placeholder

            let delegate = UITextField.GenericUITextFieldDelegate()
            delegate.didEndEditing = { _, _ in
                if field.text?.isEmpty != false {
                    alert.actions.first(where: { alertAction in alertAction.title == doneAction })!.isEnabled = false
                } else {
                    alert.actions.first(where: { alertAction in alertAction.title == doneAction })!.isEnabled = true
                }
            }
            field.delegate = delegate
        })
        alert.addAction(UIAlertAction(title: cancelAction, style: .cancel, handler: nil))
        let action = UIAlertAction(title: doneAction, style: .default,
                                   handler: actionHandler == nil ? nil : { _ in
                                       let text = alert.textFields![0].text
                                       actionHandler!(text)
                                   })
        alert.addAction(action)
        if #available(iOS 9.0, tvOS 9.0, macCatalyst 13.0, *) {
            alert.preferredAction = action
        }
        self.present(alert, animated: true, completion: completionHandler)
    }
}

extension UITextField {
    class GenericUITextFieldDelegate: NSObject, UITextFieldDelegate {
        var didEndEditing: ((UITextField, UITextField.DidEndEditingReason) -> Void)?

        func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
            self.didEndEditing?(textField, reason)
        }
    }
}
