import Foundation

struct ImageService {
    // Curated images for brain health (nature, calm, inspiring)
    // These are from Unsplash - royalty free for this use
    private static let brainPositiveImages = [
        "https://images.unsplash.com/photo-1506905925346-21bda4d32df4", // Mountain landscape
        "https://images.unsplash.com/photo-1441974231531-c6227db76b6e", // Forest path
        "https://images.unsplash.com/photo-1469474968028-56623f02e42e", // Lake reflection
        "https://images.unsplash.com/photo-1447752875215-b2761acb3c5d", // Sunset field
        "https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05", // Misty forest
        "https://images.unsplash.com/photo-1426604966848-d7adac402bff", // Mountain peak
        "https://images.unsplash.com/photo-1472214103451-9374bd1c798e", // Ocean waves
        "https://images.unsplash.com/photo-1475924156734-496f6cac6ec1", // Beach sunset
        "https://images.unsplash.com/photo-1518837695005-2083093ee35b", // Waterfall
        "https://images.unsplash.com/photo-1501594907352-04cda38ebc29", // Tropical beach
        "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b", // Snow mountain
        "https://images.unsplash.com/photo-1507525428034-b723cf961d3e", // Calm beach
    ]
    
    static func getTodaysImage() -> String {
        // Use date to pick consistent image for the day
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = dayOfYear % brainPositiveImages.count
        
        // Add Unsplash parameters for optimization
        let baseUrl = brainPositiveImages[index]
        return "\(baseUrl)?w=1080&h=1920&fit=crop&q=80"
    }
}
