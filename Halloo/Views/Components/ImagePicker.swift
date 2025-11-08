//
//  ImagePicker.swift
//  Halloo
//
//  UIKit wrapper for image selection from camera or photo library
//

import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            print("🖼️ ImagePicker: didFinishPickingMedia called")
            if let image = info[.originalImage] as? UIImage {
                print("🖼️ ImagePicker: Image found - size: \(image.size)")
                parent.image = image
                print("🖼️ ImagePicker: Image SET on parent.image")
            } else {
                print("🖼️ ImagePicker: ❌ No image found in info dictionary")
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("🖼️ ImagePicker: User cancelled")
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
