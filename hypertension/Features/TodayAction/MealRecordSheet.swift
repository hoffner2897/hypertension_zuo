import PhotosUI
import SwiftUI
import UIKit

struct MealRecordSheet: View {
    let item: TodayActionItem
    let existingRecord: MealRecord?
    let onSaved: (MealRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var record: MealRecord?
    @State private var selectedImage: UIImage?
    @State private var selectedImageData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isReplacing = false
    @State private var isAnalyzing = false
    @State private var errorMessage: String?

    private let service = MealRecordService()

    init(item: TodayActionItem, existingRecord: MealRecord?, onSaved: @escaping (MealRecord) -> Void) {
        self.item = item
        self.existingRecord = existingRecord
        self.onSaved = onSaved
        _record = State(initialValue: existingRecord)
    }

    private var mealKind: MealKind? {
        MealKind(actionTitle: item.title)
    }

    private var isShowingResult: Bool {
        record != nil && !isReplacing
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    photoArea

                    if isShowingResult {
                        recordedLabel
                        resultSections
                        replaceButton
                    } else {
                        photoButtons
                        analyzeButton
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DSTheme.Color.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(22)
                .padding(.bottom, 24)
            }
            .background(DSTheme.Color.appBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onChange(of: selectedPhotoItem) { _, item in
            Task { await loadPhoto(item) }
        }
        .sheet(isPresented: $isShowingCamera) {
            MealCameraCaptureView { image in
                setImage(image)
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack {
            Text(item.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.40))

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("关闭")
        }
    }

    private var photoArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.83, green: 0.84, blue: 0.86))

            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else if isShowingResult {
                VStack(spacing: 12) {
                    Image(item.timelineArtworkAssetName ?? "TodayCardLunch")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 150)

                    Text("餐食图片未保存")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DSTheme.Color.textSecondary)
                }
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 52, weight: .medium))
                    Text("拍照或选择照片记录\(item.title.replacingOccurrences(of: "建议", with: ""))")
                        .font(.headline)
                }
                .foregroundStyle(.white)
            }

            if isAnalyzing {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.black.opacity(0.38))
                ProgressView("AI 正在分析餐食…")
                    .tint(.white)
                    .foregroundStyle(.white)
                    .font(.headline)
            }
        }
        .frame(height: 300)
        .clipped()
    }

    private var recordedLabel: some View {
        Label("已记录", systemImage: "checkmark.circle")
            .font(.title3.weight(.bold))
            .foregroundStyle(DSTheme.Color.success)
    }

    @ViewBuilder
    private var resultSections: some View {
        if let record {
            resultBox(title: "AI分析", text: record.analysis)
            resultBox(title: "类似建议", text: record.similarSuggestion)
        }
    }

    private func resultBox(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.40))
            Text(text)
                .font(.body)
                .foregroundStyle(DSTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.88, green: 0.94, blue: 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var photoButtons: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                choiceButton("从相册选择", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.plain)
            .disabled(isAnalyzing)

            Button {
                isShowingCamera = true
            } label: {
                choiceButton("拍照", systemImage: "camera.fill")
            }
            .buttonStyle(.plain)
            .disabled(isAnalyzing || !MealCameraCaptureView.isAvailable)
        }
    }

    private func choiceButton(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(DSTheme.Color.primary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(.white)
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(DSTheme.Color.border)
            }
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var analyzeButton: some View {
        DSPrimaryButton("分析并记录", systemImage: "sparkles", isLoading: isAnalyzing) {
            Task { await analyze() }
        }
        .disabled(selectedImageData == nil || isAnalyzing)
        .opacity(selectedImageData == nil ? 0.5 : 1)
    }

    private var replaceButton: some View {
        DSSecondaryButton("重新记录", systemImage: "camera.rotate") {
            isReplacing = true
            selectedImage = nil
            selectedImageData = nil
            selectedPhotoItem = nil
            errorMessage = nil
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "无法读取这张照片，请换一张重试。"
                return
            }
            setImage(image)
        } catch {
            errorMessage = "无法读取这张照片，请换一张重试。"
        }
    }

    private func setImage(_ image: UIImage) {
        selectedImage = image
        selectedImageData = MealRecordService.uploadData(for: image)
        errorMessage = nil
    }

    private func analyze() async {
        guard !isAnalyzing, let selectedImageData, let mealKind else { return }
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }

        do {
            let savedRecord = try await service.analyze(imageData: selectedImageData, mealType: mealKind)
            record = savedRecord
            isReplacing = false
            onSaved(savedRecord)
        } catch {
            errorMessage = mealAnalysisErrorMessage(error)
        }
    }

    private func mealAnalysisErrorMessage(_ error: Error) -> String {
        if case APIClientError.server(let code, _) = error {
            switch code {
            case "AI_DAILY_QUOTA_EXCEEDED":
                return "今天的 AI 餐食分析次数已用完，请明天再试。"
            case "MEAL_IMAGE_UNCLEAR":
                return "没有清楚识别到餐食，请换一张光线更好、内容完整的照片。"
            case "PAYLOAD_TOO_LARGE":
                return "图片太大，请重新拍摄或选择另一张图片。"
            case "MEAL_ANALYSIS_UNAVAILABLE", "MEAL_ANALYSIS_FAILED":
                return "AI 餐食分析暂时不可用，请稍后重试。"
            case "UNAUTHORIZED":
                return "登录状态已失效，请重新登录后再试。"
            default:
                return "餐食分析失败，请稍后重试。"
            }
        }

        return "餐食分析失败，请检查网络后重试。"
    }
}

private struct MealCameraCaptureView: UIViewControllerRepresentable {
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
