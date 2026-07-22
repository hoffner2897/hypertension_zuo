//
//  BPCameraUploadMockView.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import Combine
import PhotosUI
import SwiftUI
import UIKit

struct BPCameraUploadMockView: View {
    @StateObject private var viewModel: BPCameraUploadViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    let onRecognized: (BPReadingDraft) -> Void
    let onManualInput: (BPReadingDraft) -> Void

    @MainActor
    init(
        onRecognized: @escaping (BPReadingDraft) -> Void,
        onManualInput: @escaping (BPReadingDraft) -> Void
    ) {
        self.init(
            recognitionService: RemoteBloodPressureRecognitionService(),
            onRecognized: onRecognized,
            onManualInput: onManualInput
        )
    }

    @MainActor
    init(
        recognitionService: any BloodPressureRecognitionService,
        onRecognized: @escaping (BPReadingDraft) -> Void,
        onManualInput: @escaping (BPReadingDraft) -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: BPCameraUploadViewModel(recognitionService: recognitionService))
        self.onRecognized = onRecognized
        self.onManualInput = onManualInput
    }

    var body: some View {
        ZStack {
            DSTheme.Color.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
                    DSSectionHeader(
                        "拍照上传",
                        subtitle: "拍摄或选择血压计屏幕照片，识别后请确认读数。",
                        systemImage: "camera.fill"
                    )

                    monitorFrame

                    DSCard {
                        VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                            instructionRow("请将血压计屏幕放入框内", systemImage: "viewfinder")
                            instructionRow("确保数字清晰可见", systemImage: "text.viewfinder")
                        }
                    }

                    if let recognitionResult = viewModel.recognitionResult {
                        recognitionSummaryCard(recognitionResult)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        errorRow(errorMessage)
                    }

                    VStack(spacing: DSTheme.Spacing.small) {
                        DSPrimaryButton(
                            "识别读数",
                            systemImage: "text.viewfinder",
                            isLoading: viewModel.isRecognizing
                        ) {
                            Task {
                                if let draft = await viewModel.recognizeReading() {
                                    onRecognized(draft)
                                }
                            }
                        }

                        HStack(spacing: DSTheme.Spacing.small) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                pickerButtonLabel("选择照片", systemImage: "photo")
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isRecognizing)

                            Button {
                                isShowingCamera = true
                            } label: {
                                pickerButtonLabel("拍照", systemImage: "camera.fill")
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isRecognizing || !CameraCaptureView.isAvailable)
                        }

                        #if DEBUG
                        DSSecondaryButton("使用内置测试图", systemImage: "photo.badge.checkmark") {
                            viewModel.loadBundledTestImage()
                        }
                        #endif

                        DSSecondaryButton("手动输入", systemImage: "square.and.pencil") {
                            onManualInput(BPReadingDraft(source: .manual))
                        }
                    }
                }
                .padding(DSTheme.Spacing.large)
            }
        }
        .navigationTitle("拍照上传")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await viewModel.loadPhoto(from: newItem)
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraCaptureView { image in
                viewModel.setCameraImage(image)
            }
            .ignoresSafeArea()
        }
    }

    private var monitorFrame: some View {
        DSCard {
            VStack(spacing: DSTheme.Spacing.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: DSTheme.Radius.large, style: .continuous)
                        .stroke(DSTheme.Color.primary, style: StrokeStyle(lineWidth: 3, dash: [10, 8]))
                        .background(
                            RoundedRectangle(cornerRadius: DSTheme.Radius.large, style: .continuous)
                                .fill(DSTheme.Color.primarySoft.opacity(0.7))
                        )

                    if let selectedImage = viewModel.selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: DSTheme.Radius.large, style: .continuous))
                    } else {
                        VStack(spacing: DSTheme.Spacing.medium) {
                            Image(systemName: "display")
                                .font(.system(size: 46, weight: .semibold))
                                .foregroundStyle(DSTheme.Color.primary)

                            Text("添加血压计照片")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(DSTheme.Color.textPrimary)

                            Text("支持拍照或从相册选择")
                                .font(.subheadline)
                                .foregroundStyle(DSTheme.Color.textSecondary)
                        }
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: DSTheme.Radius.large, style: .continuous))

                Text(viewModel.selectedImage == nil ? "尚未选择照片" : "照片已准备识别")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.textSecondary)
            }
        }
    }

    private func instructionRow(_ text: String, systemImage: String) -> some View {
        HStack(spacing: DSTheme.Spacing.medium) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(DSTheme.Color.primary)
                .frame(width: 34, height: 34)
                .background(DSTheme.Color.primarySoft)
                .clipShape(Circle())

            Text(text)
                .font(.body.weight(.semibold))
                .foregroundStyle(DSTheme.Color.textPrimary)
        }
    }

    private func recognitionSummaryCard(_ result: BPRecognitionResult) -> some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.small) {
                HStack(spacing: DSTheme.Spacing.small) {
                    Image(systemName: result.needsManualReview ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(result.needsManualReview ? DSTheme.Color.warning : DSTheme.Color.success)

                    Text("识别结果待确认")
                        .font(.headline)
                        .foregroundStyle(DSTheme.Color.textPrimary)
                }

                Text(result.notes ?? "照片识别可能不完全准确，请在下一步确认读数。")
                    .font(.subheadline)
                    .foregroundStyle(DSTheme.Color.textSecondary)

                Text("置信度 \(Int(result.confidence * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.textSecondary)
            }
        }
    }

    private func errorRow(_ message: String) -> some View {
        HStack(alignment: .top, spacing: DSTheme.Spacing.small) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(DSTheme.Color.warning)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DSTheme.Color.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DSTheme.Spacing.small)
    }

    private func pickerButtonLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: DSTheme.Spacing.small) {
            Image(systemName: systemImage)
                .font(.headline)

            Text(title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(DSTheme.Color.primary)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 52)
        .padding(.horizontal, DSTheme.Spacing.medium)
        .background(DSTheme.Color.cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous)
                .stroke(DSTheme.Color.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        BPCameraUploadMockView(onRecognized: { _ in }, onManualInput: { _ in })
    }
}

@MainActor
final class BPCameraUploadViewModel: ObservableObject {
    @Published private(set) var isRecognizing = false
    @Published private(set) var selectedImage: UIImage?
    @Published private(set) var recognitionResult: BPRecognitionResult?
    @Published private(set) var errorMessage: String?

    private let recognitionService: any BloodPressureRecognitionService
    private var selectedImageData: Data?

    init(recognitionService: any BloodPressureRecognitionService) {
        self.recognitionService = recognitionService
    }

    func recognizeReading() async -> BPReadingDraft? {
        guard !isRecognizing else {
            return nil
        }

        isRecognizing = true
        errorMessage = nil

        do {
            let result = try await recognitionService.recognizeReading(from: selectedImageData)
            recognitionResult = result
            isRecognizing = false
            return result.draft
        } catch {
            recognitionResult = nil
            errorMessage = recognitionErrorMessage(error)
            isRecognizing = false
            return nil
        }
    }

    func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else {
            return
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "无法读取这张照片，请换一张重试。"
                return
            }

            setImage(image, data: Self.uploadData(for: image) ?? data)
        } catch {
            errorMessage = "无法读取这张照片，请换一张重试。"
        }
    }

    func setCameraImage(_ image: UIImage) {
        setImage(image, data: Self.uploadData(for: image))
    }

    #if DEBUG
    func loadBundledTestImage() {
        guard let image = UIImage(named: "TodayCardMorningBloodPressure") else {
            errorMessage = "内置测试图片不可用。"
            return
        }
        setCameraImage(image)
    }
    #endif

    private func setImage(_ image: UIImage, data: Data?) {
        selectedImage = image
        selectedImageData = data
        recognitionResult = nil
        errorMessage = nil
    }

    private func recognitionErrorMessage(_ error: Error) -> String {
        if case APIClientError.server(let code, _) = error {
            switch code {
            case "AI_DAILY_QUOTA_EXCEEDED":
                return "今天的 AI 图片识别次数已用完，请手动输入读数或明天再试。"
            case "BAD_REQUEST", "VALIDATION_FAILED":
                return "这张图片无法用于识别，请重新拍摄或手动输入。"
            case "UNAUTHORIZED":
                return "登录状态已失效，请重新登录后再试。"
            default:
                return "暂时无法识别照片，请稍后重试或手动输入。"
            }
        }

        return (error as? BPRecognitionError)?.errorDescription
            ?? "暂时无法识别照片，请稍后重试或手动输入。"
    }

    private static func uploadData(for image: UIImage) -> Data? {
        let maxDimension: CGFloat = 1400
        let largestSide = max(image.size.width, image.size.height)
        guard largestSide > maxDimension else {
            return image.jpegData(compressionQuality: 0.78)
        }

        let scale = maxDimension / largestSide
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resizedImage.jpegData(compressionQuality: 0.78)
    }
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onCapture: (UIImage) -> Void
        private let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
