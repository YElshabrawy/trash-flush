import AppKit
import Lottie
import SwiftUI

/// A one-shot confetti burst: "Confetti Burst" by Ann Sniechowski on
/// LottieFiles, under the Lottie Simple License.
struct ConfettiView: View {
    var body: some View {
        LottieClip(animation: LottieClip.confetti, loops: false)
    }
}

/// Plays a bundled Lottie animation from the moment it appears.
struct LottieClip: NSViewRepresentable {
    static let confetti = load("confetti-burst")

    let animation: LottieAnimation?
    var loops = false
    var speed = 1.0

    func makeNSView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView(animation: animation)
        view.loopMode = loops ? .loop : .playOnce
        view.animationSpeed = speed
        view.contentMode = .scaleAspectFit
        view.play()
        return view
    }

    func updateNSView(_ view: LottieAnimationView, context: Context) {}

    private static func load(_ name: String) -> LottieAnimation? {
        resourceURL(name, "json").flatMap { LottieAnimation.filepath($0.path) }
    }

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
