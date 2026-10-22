import Foundation

/// Meldet Änderungen in einem Ordner per Kernel-Event, ohne Polling.
/// Beobachtet wird der Ordner statt der Datei, weil das atomare Schreiben
/// die Datei ersetzt und ein Handle auf die alte Datei nichts mehr melden würde.
final class DirectoryWatcher {
    private let source: DispatchSourceFileSystemObject

    /// `onChange` läuft auf der Main-Queue.
    init?(url: URL, onChange: @escaping @Sendable () -> Void) {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return nil }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler(handler: onChange)
        source.setCancelHandler { close(descriptor) }
        source.resume()
    }

    deinit {
        source.cancel()
    }
}
