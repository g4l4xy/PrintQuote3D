import Foundation
private final class ResourceMarker {}
enum TestResources {
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle(for: ResourceMarker.self)
        #endif
    }
}
