//
//  TextExtractor.swift
//  Doggo
//
//  Created by Sorest on 1/19/26.
//

import Foundation
import PDFKit
import UniformTypeIdentifiers

struct TextExtractor {
    
    /// The main entry point. Pass a file URL, get the raw text content.
    static func extractText(from url: URL) -> String? {
        // 1. Check file extension
        let ext = url.pathExtension.lowercased()
        
        if ext == "pdf" {
            return extractPDF(url: url)
        } else if ext == "docx" || ext == "doc" {
            // iOS cannot natively read .docx text without external libraries.
            // We return a helpful message so the AI "Parser" knows what happened.
            print("⚠️ Native .docx reading is not supported on iOS.")
            return "ERROR: Please convert this Word document to PDF or Text before importing."
        } else {
            // Fallback for plain text or unknown types
            // FIXED: Added encoding to silence deprecation warning
            return try? String(contentsOf: url, encoding: .utf8)
        }
    }
    
    // MARK: - PDF Extraction
    private static func extractPDF(url: URL) -> String? {
        guard let pdfDocument = PDFDocument(url: url) else { return nil }
        var fullText = ""
        
        // Loop through all pages and append text
        for i in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: i) {
                fullText += (page.string ?? "") + "\n"
            }
        }
        
        return fullText.isEmpty ? nil : fullText
    }
    
    // REMOVED: extractRichText function because .word support does not exist in iOS NSAttributedString.
}

