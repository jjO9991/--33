import PDFKit
import UIKit
import ZIPFoundation

actor FileImportService {
    static let shared = FileImportService()

    func extractText(from url: URL) async throws -> String {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "txt":
            return try String(contentsOf: url, encoding: .utf8)

        case "pdf":
            guard let pdf = PDFDocument(url: url) else {
                throw NSError(
                    domain: "FileImport",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "无法读取 PDF 文件"]
                )
            }
            var text = ""
            for i in 0..<pdf.pageCount {
                if let page = pdf.page(at: i), let pageText = page.string {
                    text += pageText + "\n"
                }
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)

        case "docx":
            // DOCX 是 ZIP 包，解压后取 word/document.xml
            let tmpDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

            guard let archive = Archive(url: url, accessMode: .read) else {
                throw NSError(
                    domain: "FileImport",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "无法打开 DOCX 文件"]
                )
            }

            // 解压
            for entry in archive {
                let dest = tmpDir.appendingPathComponent(entry.path)
                if entry.type == .directory {
                    try? FileManager.default.createDirectory(
                        at: dest, withIntermediateDirectories: true
                    )
                } else {
                    try? FileManager.default.createDirectory(
                        at: dest.deletingLastPathComponent(), withIntermediateDirectories: true
                    )
                    _ = try? archive.extract(entry, to: dest)
                }
            }

            let xmlPath = tmpDir.appendingPathComponent("word/document.xml")
            guard FileManager.default.fileExists(atPath: xmlPath.path) else {
                try? FileManager.default.removeItem(at: tmpDir)
                throw NSError(
                    domain: "FileImport",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "DOCX 文件结构异常"]
                )
            }

            let xmlData = try Data(contentsOf: xmlPath)
            let xmlStr = String(data: xmlData, encoding: .utf8) ?? ""
            // 简易 XML 清洗：去标签取文本
            let text = xmlStr
                .replacingOccurrences(of: "<[^>]+>", with: "\n", options: .regularExpression)
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")

            try? FileManager.default.removeItem(at: tmpDir)
            return text

        default:
            throw NSError(
                domain: "FileImport",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "不支持的格式：\(ext)，请选择 PDF/DOCX/TXT"]
            )
        }
    }
}
