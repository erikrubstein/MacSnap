import AppKit
import CoreGraphics

struct DisplayIdentity: Hashable {
    let id: String
    let name: String

    init(screen: NSScreen) {
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        let displayUUID = displayID.flatMap(Self.displayUUIDString)
        let fallbackID = displayID.map { "display-\($0)" } ?? "frame-\(Int(screen.frame.minX))-\(Int(screen.frame.minY))-\(Int(screen.frame.width))-\(Int(screen.frame.height))"

        id = displayUUID ?? fallbackID
        name = screen.localizedName
    }

    private static func displayUUIDString(for displayID: CGDirectDisplayID) -> String? {
        guard let unmanagedUUID = CGDisplayCreateUUIDFromDisplayID(displayID) else {
            return nil
        }

        let uuid = unmanagedUUID.takeRetainedValue()
        return CFUUIDCreateString(nil, uuid) as String
    }
}
