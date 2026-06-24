//
//  DocumentPicker.swift
//  Doggo
//
//  Created by Sorest on 1/19/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [
            .pdf,
            .plainText,
            UTType("org.openxmlformats.wordprocessingml.document") ?? .text
        ]
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let sourceURL = urls.first else { return }
            
            // 1. Secure Access Request
            let canAccess = sourceURL.startAccessingSecurityScopedResource()
            defer { if canAccess { sourceURL.stopAccessingSecurityScopedResource() } }
            
            // 2. Copy to "Temp" (CRITICAL FIX)
            // We cannot reliably read the file directly from the picker's URL.
            // We must copy it to our app's temporary directory first.
            do {
                let tempDir = FileManager.default.temporaryDirectory
                let tempURL = tempDir.appendingPathComponent(sourceURL.lastPathComponent)
                
                // Cleanup old file if it exists
                try? FileManager.default.removeItem(at: tempURL)
                
                // Perform the copy
                try FileManager.default.copyItem(at: sourceURL, to: tempURL)
                
                DLog("✅ File copied to: \(tempURL.path)")
                
                // 3. Hand off the SAFE, COPIED url
                parent.onPick(tempURL)
                
            } catch {
                DLog("❌ Failed to copy file: \(error.localizedDescription)")
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            DLog("⚠️ Document picker cancelled")
        }
    }
}

