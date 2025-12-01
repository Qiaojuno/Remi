//
//  ImageCacheService.swift
//  Halloo
//
//  Purpose: Memory-based image caching for profile photos
//  Prevents AsyncImage flicker when switching tabs by pre-loading images
//
//  Created by Claude Code on 2025-10-21
//

import SwiftUI
import Combine

/// Memory-based image cache for profile photos
///
/// This service pre-loads profile photos into memory when profiles are loaded,
/// eliminating the brief "empty state" flicker from AsyncImage when switching tabs.
///
/// ## Architecture:
/// - Uses NSCache for automatic memory management
/// - Pre-loads images when profiles are added to AppState
/// - Provides synchronous access to cached images
/// - Cleans up automatically when memory pressure occurs
///
/// ## Usage:
/// ```swift
/// // Pre-load profile photos
/// await imageCache.preloadProfileImages(profiles)
///
/// // Get cached image synchronously
/// if let image = imageCache.getCachedImage(for: profilePhotoURL) {
///     // Use image directly
/// }
/// ```
final class ImageCacheService: ObservableObject {

    // MARK: - Cache Storage

    /// Memory-based cache using NSCache for automatic memory management
    /// NSCache automatically evicts objects when memory pressure occurs
    private let cache = NSCache<NSString, UIImage>()

    /// Published dictionary for SwiftUI reactive updates
    /// Maps photo URL to loaded status (allows views to observe loading state)
    @Published private(set) var loadedImages: Set<String> = []

    // MARK: - Initialization

    init() {
        // Configure cache limits
        // Account for: Profile photos (4-10) + Gallery photos (20-50) + Card stack (5-10)
        cache.countLimit = 100 // Max 100 images in memory
        cache.totalCostLimit = 150 * 1024 * 1024 // 150MB limit for all photos
        // NSCache will automatically evict oldest images when memory pressure occurs
    }

    // MARK: - Public API

    /// Get cached image synchronously (no flicker)
    ///
    /// - Parameter url: The photo URL string
    /// - Returns: Cached UIImage if available, nil otherwise
    func getCachedImage(for url: String?) -> UIImage? {
        guard let url = url, !url.isEmpty else { return nil }
        return cache.object(forKey: url as NSString)
    }

    /// Remove cached image for a specific URL
    ///
    /// - Parameter url: The photo URL string to remove from cache
    func removeCachedImage(for url: String?) {
        guard let url = url, !url.isEmpty else { return }
        cache.removeObject(forKey: url as NSString)
        loadedImages.remove(url)
    }

    /// Get cached image for a gallery event (by event ID)
    ///
    /// - Parameter eventId: The gallery event ID
    /// - Returns: Cached UIImage if available, nil otherwise
    func getCachedGalleryImage(for eventId: String) -> UIImage? {
        let cacheKey = "gallery-event-\(eventId)"
        return cache.object(forKey: cacheKey as NSString)
    }

    /// Pre-load profile images into cache
    ///
    /// Call this when profiles are loaded to pre-populate the cache.
    /// Images are loaded asynchronously in parallel.
    ///
    /// - Parameter profiles: Array of profiles with photoURL to cache
    func preloadProfileImages(_ profiles: [ElderlyProfile]) async {
        // Load all profile images in parallel
        await withTaskGroup(of: Void.self) { group in
            for profile in profiles {
                guard let urlString = profile.photoURL,
                      !urlString.isEmpty,
                      let url = URL(string: urlString) else {
                    continue
                }

                // Skip if already cached
                if cache.object(forKey: urlString as NSString) != nil {
                    continue
                }

                group.addTask {
                    await self.loadAndCacheImage(url: url, key: urlString, profileName: profile.name)
                }
            }
        }
    }

    /// Pre-load gallery photos into cache
    ///
    /// Call this when gallery events are loaded to pre-populate the cache.
    /// Caches both profile creation photos (photoURL) and task response photos (photoData).
    ///
    /// - Parameter events: Array of gallery events with photos to cache
    func preloadGalleryPhotos(_ events: [GalleryHistoryEvent]) async {
        // Load all gallery photos in parallel
        await withTaskGroup(of: Void.self) { group in
            for event in events {
                switch event.eventData {
                case .profileCreated(let data):
                    // Profile creation photos (photoURL) - download from Firebase Storage
                    guard let urlString = data.photoURL,
                          !urlString.isEmpty,
                          let url = URL(string: urlString) else {
                        continue
                    }

                    // Skip if already cached (might be a profile photo too!)
                    if cache.object(forKey: urlString as NSString) != nil {
                        continue
                    }

                    group.addTask {
                        await self.loadAndCacheImage(url: url, key: urlString, profileName: "Gallery-\(event.id)")
                    }

                case .taskResponse(let data):
                    // Task response photos (photoData) - already downloaded, just cache UIImage
                    guard let photoData = data.photoData else {
                        continue
                    }

                    // Use event ID as cache key for photoData
                    let cacheKey = "gallery-event-\(event.id)"

                    // Skip if already cached
                    if cache.object(forKey: cacheKey as NSString) != nil {
                        continue
                    }

                    group.addTask {
                        await self.cacheImageFromData(photoData, key: cacheKey, eventId: event.id)
                    }
                }
            }
        }
    }

    /// Cache a UIImage from Data (for photoData from MMS responses)
    ///
    /// - Parameters:
    ///   - data: The image data (already decoded from base64)
    ///   - key: The cache key (event ID)
    ///   - eventId: Event ID for logging
    private func cacheImageFromData(_ data: Data, key: String, eventId: String) async {
        // Create UIImage from data
        guard let image = UIImage(data: data) else {
            print("❌ [ImageCache] Failed to create image from photoData for event \(eventId)")
            return
        }

        // Cache the image with cost (estimated memory size)
        let cost = data.count
        await MainActor.run {
            cache.setObject(image, forKey: key as NSString, cost: cost)
            loadedImages.insert(key)
        }
    }

    /// Load a single image and cache it
    ///
    /// - Parameters:
    ///   - url: The image URL
    ///   - key: The cache key (usually the URL string)
    ///   - profileName: Profile name for logging
    private func loadAndCacheImage(url: URL, key: String, profileName: String) async {
        do {
            // Download image data
            let (data, response) = try await URLSession.shared.data(from: url)

            // Validate response
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ [ImageCache] Invalid response for \(profileName)")
                return
            }

            // Create UIImage from data
            guard let image = UIImage(data: data) else {
                print("❌ [ImageCache] Failed to create image for \(profileName)")
                return
            }

            // Cache the image with cost (estimated memory size)
            let cost = data.count
            await MainActor.run {
                cache.setObject(image, forKey: key as NSString, cost: cost)
                loadedImages.insert(key)
            }

        } catch {
            print("❌ [ImageCache] Failed to load image for \(profileName): \(error.localizedDescription)")
        }
    }

    /// Remove specific image from cache
    ///
    /// - Parameter url: The photo URL to remove
    func removeImage(for url: String?) {
        guard let url = url, !url.isEmpty else { return }
        cache.removeObject(forKey: url as NSString)
        loadedImages.remove(url)
    }

    /// Clear all cached images
    func clearCache() {
        cache.removeAllObjects()
        loadedImages.removeAll()
    }
}
