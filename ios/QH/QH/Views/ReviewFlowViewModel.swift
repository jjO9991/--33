import Foundation
import SwiftUI
import UIKit

enum ReviewStep {
    case input
    case analyzing
    case result
}

@MainActor
final class ReviewFlowViewModel: ObservableObject {
    @Published var contractText: String = ""
    @Published var userRole: String = ""
    @Published var risks: [RiskCard] = []
    @Published var summary: ReviewSummary? = nil
    @Published var isAnalyzing: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var currentStep: ReviewStep = .input
    // OCR 相关
    @Published var isRecognizingText: Bool = false
    @Published var showCamera: Bool = false
    @Published var showPhotoPicker: Bool = false
    @Published var showFileImporter: Bool = false

    private let api = APIClient.shared

    var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "simulator"
    }

    func startReview() async {
        let text = contractText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            errorMessage = "请先粘贴合同文本"
            showError = true
            return
        }
        isAnalyzing = true
        currentStep = .analyzing
        errorMessage = ""
        showError = false

        do {
            let session = try await api.createSession(deviceId: deviceId, type: "review")
            let result = try await api.analyzeReview(
                sessionId: session.id,
                text: text,
                userRole: userRole,
            )
            if result.status == "completed" || result.status == "empty" {
                risks = result.risks
                summary = result.summary
                currentStep = .result
            } else {
                errorMessage = "审查未完成：\(result.status)"
                showError = true
                currentStep = .input
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            currentStep = .input
        }

        isAnalyzing = false
    }

    func processImage(_ image: UIImage) {
        isRecognizingText = true
        Task {
            do {
                let text = try await OCRService.shared.recognizeText(from: image)
                await MainActor.run {
                    if contractText.isEmpty {
                        contractText = text
                    } else {
                        contractText = contractText + "\n\n" + text
                    }
                    isRecognizingText = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "文字识别失败：\(error.localizedDescription)"
                    showError = true
                    isRecognizingText = false
                }
            }
        }
    }

    func importFile(_ url: URL) {
        isRecognizingText = true
        Task {
            do {
                let text = try await FileImportService.shared.extractText(from: url)
                await MainActor.run {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if contractText.isEmpty {
                        contractText = trimmed
                    } else {
                        contractText = contractText + "\n\n" + trimmed
                    }
                    isRecognizingText = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isRecognizingText = false
                }
            }
        }
    }

    convenience init(restoreSessionId: String) {
        self.init()
        Task { await restoreReview(restoreSessionId) }
    }

    private func restoreReview(_ sessionId: String) async {
        currentStep = .analyzing
        do {
            let detail = try await api.getReviewDetail(sessionId: sessionId)
            await MainActor.run {
                if let summary = detail.summary {
                    self.summary = summary
                    self.risks = detail.risks
                    self.currentStep = .result
                } else {
                    self.errorMessage = "该审查记录无结果"
                    self.showError = true
                    self.currentStep = .input
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                currentStep = .input
            }
        }
    }

    func reset() {
        contractText = ""
        userRole = ""
        risks = []
        summary = nil
        isAnalyzing = false
        showError = false
        errorMessage = ""
        currentStep = .input
        isRecognizingText = false
        showCamera = false
        showPhotoPicker = false
        showFileImporter = false
    }
}
