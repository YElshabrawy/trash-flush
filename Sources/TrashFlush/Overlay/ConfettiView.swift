import AppKit
import Lottie
import SwiftUI

/// A one-shot confetti burst: "Confetti Burst" by Ann Sniechowski on
/// LottieFiles, under the Lottie Simple License.
struct ConfettiView: NSViewRepresentable {
    private static let animation = resourceURL("confetti-burst", "json").flatMap { LottieAnimation.filepath($0.path) }

    func makeNSView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView(animation: Self.animation)
        view.loopMode = .playOnce
        view.contentMode = .scaleAspectFit
        view.play()
        return view
    }

    func updateNSView(_ view: LottieAnimationView, context: Context) {}

    /// SwiftPM's generated `Bundle.module` only looks next to the executable and
    /// crashes when the bundle isn't there. `build-app.sh` copies it into
    /// Contents/Resources instead, so look in both places.
    private static func resourceURL(_ name: String, _ ext: String) -> URL? {
        let bundleName = "TrashFlush_TrashFlush.bundle"
        let places = [Bundle.main.resourceURL, Bundle.main.bundleURL].compactMap { $0 }
        for place in places {
            if let bundle = Bundle(url: place.appendingPathComponent(bundleName)),
               let url = bundle.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}
