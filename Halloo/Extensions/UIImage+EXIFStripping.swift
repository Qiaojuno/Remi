//
//  UIImage+EXIFStripping.swift
//  Halloo
//
//  Purpose: Strip EXIF metadata from images before upload for privacy protection
//  Created: 2025-11-06
//
//  PRIVACY: Removes GPS location, device info, and timestamps from photos
//  GDPR Compliance: Minimizes personal data collection from image metadata
//

import UIKit

extension UIImage {
    /// Strips EXIF metadata from image by re-rendering it
    ///
    /// This method removes all embedded metadata including:
    /// - GPS location coordinates
    /// - Device information (model, iOS version)
    /// - Camera settings (aperture, focal length, etc.)
    /// - Timestamps and dates
    /// - Photo editing history
    /// - Device owner name
    ///
    /// - Parameter compressionQuality: JPEG compression quality (0.0 to 1.0, default 0.8)
    /// - Returns: JPEG data without EXIF metadata, or nil if conversion fails
    ///
    /// - Important: This is critical for elderly care app privacy where photos may reveal:
    ///   - Home addresses (GPS coordinates)
    ///   - Activity patterns (timestamps)
    ///   - Vulnerable individual locations
    func jpegDataWithoutEXIF(compressionQuality: CGFloat = 0.8) -> Data? {
        // Re-render the image to strip all metadata
        // UIGraphicsBeginImageContext creates a new clean image without metadata
        UIGraphicsBeginImageContext(self.size)
        defer { UIGraphicsEndImageContext() }

        // Draw the original image into the new context
        self.draw(in: CGRect(origin: .zero, size: self.size))

        // Get the newly rendered image (without any metadata)
        guard let newImage = UIGraphicsGetImageFromCurrentImageContext() else {
            print("❌ [UIImage+EXIF] Failed to render image without EXIF")
            return nil
        }

        // Convert to JPEG data (no metadata will be included)
        let jpegData = newImage.jpegData(compressionQuality: compressionQuality)

        if let data = jpegData {
            print("✅ [UIImage+EXIF] Stripped EXIF metadata - size: \(data.count) bytes")
        } else {
            print("❌ [UIImage+EXIF] Failed to convert stripped image to JPEG")
        }

        return jpegData
    }
}
