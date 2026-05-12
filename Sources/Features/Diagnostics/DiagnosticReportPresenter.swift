import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
protocol DiagnosticReportPresenting {
    func export(report: DiagnosticReport) throws -> URL?
}

@MainActor
struct SystemDiagnosticReportPresenter: DiagnosticReportPresenting {
    func export(report: DiagnosticReport) throws -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Diagnostic Report"
        panel.prompt = "Export"
        panel.nameFieldStringValue = "CodexPill-Diagnostic-\(filenameTimestamp(from: report.system.exportTimestamp)).json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(report)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func filenameTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
