import SwiftUI
import UIKit

// opens the system camera ui

// only returns the original image (no edits) and passes it back via onPick

struct CameraPicker: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    // UIKit delegates live in a Coordinator so SwiftUI can talk to UIImagePickerController

    // This forwards "picked image" + "cancel" back to SwiftUI

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onPick: (UIImage) -> Void
        let dismiss: () -> Void

        init(onPick: @escaping (UIImage) -> Void, dismiss: @escaping () -> Void) {
            self.onPick = onPick
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            DispatchQueue.main.async {
                self.dismiss()
            }
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

            // sometimes the callback comes in off the main thread, so keep it safe

            let img =
                (info[.originalImage] as? UIImage) ??
                (info[.editedImage] as? UIImage)

            DispatchQueue.main.async {
                if let img { self.onPick(img) }
                self.dismiss()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, dismiss: { dismiss() })
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()

        // safety: if camera isn't available, just close (ContentView already guards too)

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            DispatchQueue.main.async { dismiss() }
            return picker
        }

        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.mediaTypes = ["public.image"]
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}
