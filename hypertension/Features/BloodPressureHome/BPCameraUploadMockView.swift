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
    @Environment(\.dismiss) private var dismiss
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
                VStack(alignment: .leading, spacing: 18) {
                    uploadHeader
                    monitorFrame

                    if let errorMessage = viewModel.errorMessage {
                        errorRow(errorMessage)
                    }

                    VStack(spacing: 12) {
                        Button {
                            if CameraCaptureView.isAvailable {
                                isShowingCamera = true
                            } else {
                                viewModel.showCameraUnavailableMessage()
                            }
                        } label: {
                            uploadPrimaryButtonLabel
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isRecognizing)

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Text("从相册选择")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(DSTheme.Color.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(.white)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .stroke(DSTheme.Color.primary, lineWidth: 1.1)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isRecognizing)
                    }
                }
                .padding(.horizontal, DSTheme.Spacing.large)
                .padding(.top, DSTheme.Spacing.medium)
                .padding(.bottom, 104)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await viewModel.loadPhoto(from: newItem)
                await recognizeLoadedImage()
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraCaptureView { image in
                viewModel.setCameraImage(image)
                Task {
                    await recognizeLoadedImage()
                }
            }
            .ignoresSafeArea()
        }
    }

    private var uploadHeader: some View {
        VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
            HStack(alignment: .top) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(DSTheme.Color.primary)
                        .frame(width: 40, height: 40)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("拍照上传")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))

                Text("请将血压计屏幕放入取景框内。")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))
            }
        }
    }

    private var monitorFrame: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                if let selectedImage = viewModel.selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    BPMonitorSamplePhoto()
                }

                CameraFocusCorners()
                    .padding(30)

                if viewModel.isRecognizing {
                    ProgressView()
                        .tint(.white)
                        .padding(14)
                        .background(.black.opacity(0.44))
                        .clipShape(Circle())
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(0.94, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .clipped()

            Text(viewModel.selectedImage == nil ? "保持画面清晰，避免反光" : "正在准备识别，请保持读数清晰")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 9)
                .background(.black.opacity(0.58))
                .clipShape(Capsule())
                .padding(.bottom, 18)
        }
    }

    private var uploadPrimaryButtonLabel: some View {
        HStack(spacing: DSTheme.Spacing.small) {
            if viewModel.isRecognizing {
                ProgressView()
                    .tint(.white)
            }

            Text(viewModel.isRecognizing ? "识别中..." : "拍摄血压计屏幕")
                .font(.headline.weight(.bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(DSTheme.Color.primary)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func recognizeLoadedImage() async {
        guard viewModel.selectedImage != nil else {
            return
        }

        if let draft = await viewModel.recognizeReading() {
            onRecognized(draft)
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

private struct BPMonitorSamplePhoto: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.82, green: 0.80, blue: 0.72),
                    Color(red: 0.94, green: 0.89, blue: 0.80)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.32))
                .frame(width: 170, height: 170)
                .blur(radius: 28)
                .offset(x: -130, y: -170)

            Rectangle()
                .fill(Color(red: 0.76, green: 0.68, blue: 0.56).opacity(0.42))
                .frame(height: 96)
                .offset(y: 182)

            Image("BPReadingMonitorHero")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 310)
                .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 12)
                .padding(.horizontal, 24)
        }
    }
}

private struct CameraFocusCorners: View {
    var body: some View {
        GeometryReader { proxy in
            let cornerSize: CGFloat = 34

            ZStack {
                FocusCorner()
                    .frame(width: cornerSize, height: cornerSize)
                    .position(x: cornerSize / 2, y: cornerSize / 2)

                FocusCorner()
                    .scaleEffect(x: -1, y: 1)
                    .frame(width: cornerSize, height: cornerSize)
                    .position(x: proxy.size.width - cornerSize / 2, y: cornerSize / 2)

                FocusCorner()
                    .scaleEffect(x: 1, y: -1)
                    .frame(width: cornerSize, height: cornerSize)
                    .position(x: cornerSize / 2, y: proxy.size.height - cornerSize / 2)

                FocusCorner()
                    .scaleEffect(x: -1, y: -1)
                    .frame(width: cornerSize, height: cornerSize)
                    .position(x: proxy.size.width - cornerSize / 2, y: proxy.size.height - cornerSize / 2)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct FocusCorner: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 1.5, y: 31))
            path.addLine(to: CGPoint(x: 1.5, y: 8))
            path.addQuadCurve(to: CGPoint(x: 8, y: 1.5), control: CGPoint(x: 1.5, y: 1.5))
            path.addLine(to: CGPoint(x: 31, y: 1.5))
        }
        .stroke(
            Color(red: 0.03, green: 0.33, blue: 1.0),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )
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

    func showCameraUnavailableMessage() {
        errorMessage = "当前设备不支持相机，请从相册选择照片。"
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
