import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(0)
            HistoryView(selectedTab: $selectedTab)
                .tabItem {
                    Label("历史", systemImage: "clock.fill")
                }
                .tag(1)
            SettingsView()
                .tabItem {
                    Label("我的", systemImage: "person")
                }
                .tag(2)
        }
        .accentColor(.mint)
    }
}

struct HomeView: View {
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                Color(red: 0.965, green: 0.976, blue: 0.984)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.17, blue: 0.31),
                        Color(red: 0.10, green: 0.25, blue: 0.44)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 310)
                .ignoresSafeArea(edges: .top)

                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 128))
                    .foregroundColor(.white.opacity(0.08))
                    .offset(x: 120, y: 82)

                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        QiHeLogoMark()
                            .frame(width: 78, height: 78)

                        Text("契 合")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.white)

                        HStack(spacing: 12) {
                            Rectangle().frame(width: 24, height: 1)
                            Text("AI 合同助手 · 懂法律，更懂你")
                                .font(.system(size: 16, weight: .medium))
                            Rectangle().frame(width: 24, height: 1)
                        }
                        .foregroundColor(Color(red: 0.76, green: 0.93, blue: 0.96))
                    }
                    .padding(.top, 28)

                    HomeChatCard()
                        .padding(.horizontal, 20)

                    HStack(spacing: 12) {
                        HomeActionCard(
                            title: "合同生成",
                            subtitle: "根据您的需求\n定制专属合同",
                            kind: .draft,
                            tint: Color(red: 0.26, green: 0.76, blue: 0.62),
                            destination: DraftFlowView()
                        )

                        HomeActionCard(
                            title: "合同审查",
                            subtitle: "AI 智能审查合同风险\n提供修改建议",
                            kind: .review,
                            tint: Color(red: 0.22, green: 0.50, blue: 0.96),
                            destination: ReviewFlowView()
                        )
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - 契合 Logo 印章

struct QiHeLogoMark: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // 深色圆角底
                RoundedRectangle(cornerRadius: s * 0.22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.13, blue: 0.26),
                                Color(red: 0.09, green: 0.22, blue: 0.40)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: s * 0.22, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.41, green: 0.88, blue: 0.75).opacity(0.35),
                                        Color(red: 0.50, green: 0.70, blue: 1.0).opacity(0.35)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: s * 0.018
                            )
                    )

                // 双线对弧 — 抽象「合」
                QiHeMark()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.41, green: 0.88, blue: 0.75),
                                Color(red: 0.30, green: 0.62, blue: 1.0),
                                Color(red: 0.55, green: 0.75, blue: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(
                            lineWidth: s * 0.095,
                            lineCap: .round
                        )
                    )
                    .frame(width: s * 0.42, height: s * 0.32)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// 两笔对弧从上下两侧向中心拱起、交汇 → 抽象的「合」（契合/契约）
/// 视觉：两笔环抱中心一点，似两手相握、似印章篆书的「合」
private struct QiHeMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let midX = w * 0.5
        var p = Path()

        // 上笔：从左上弧向中心下方
        p.move(to: CGPoint(x: w * 0.18, y: h * 0.30))
        p.addQuadCurve(
            to: CGPoint(x: w * 0.82, y: h * 0.30),
            control: CGPoint(x: midX, y: h * 0.58)
        )

        // 下笔：从右上弧向左下，穿过上笔形成交织
        p.move(to: CGPoint(x: w * 0.82, y: h * 0.52))
        p.addQuadCurve(
            to: CGPoint(x: w * 0.18, y: h * 0.52),
            control: CGPoint(x: midX, y: h * 0.24)
        )

        return p
    }
}


struct HomeActionCard<Destination: View>: View {
    enum CardKind {
        case draft
        case review
    }

    let title: String
    let subtitle: String
    let kind: CardKind
    let tint: Color
    let destination: Destination

    var body: some View {
        NavigationLink(destination: destination) {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(red: 0.06, green: 0.12, blue: 0.25))

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(Color(red: 0.30, green: 0.36, blue: 0.48))
                        .lineSpacing(4)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(tint)
                        .clipShape(Circle())
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if kind == .draft {
                    DraftCardArtwork()
                        .frame(width: 92, height: 100)
                        .offset(x: 5, y: -18)
                } else {
                    ReviewCardArtwork()
                        .frame(width: 92, height: 100)
                        .offset(x: 5, y: -15)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [tint.opacity(0.15), .white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

struct DraftCardArtwork: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.white)
                .shadow(color: .mint.opacity(0.25), radius: 10, x: 0, y: 8)
                .rotationEffect(.degrees(7))
            VStack(alignment: .leading, spacing: 8) {
                ForEach([42, 54, 46, 30], id: \.self) { width in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(red: 0.44, green: 0.82, blue: 0.72))
                        .frame(width: CGFloat(width), height: 5)
                }
                Spacer()
            }
            .padding(18)
            Image(systemName: "pencil")
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(Color(red: 0.26, green: 0.76, blue: 0.62))
                .rotationEffect(.degrees(38))
                .offset(x: 22, y: 24)
        }
    }
}

struct ReviewCardArtwork: View {
    var body: some View {
        ZStack {
            Image(systemName: "shield.fill")
                .font(.system(size: 86))
                .foregroundStyle(
                    LinearGradient(colors: [Color(red: 0.55, green: 0.78, blue: 1), Color(red: 0.12, green: 0.42, blue: 0.96)], startPoint: .top, endPoint: .bottom)
                )
            Image(systemName: "shield")
                .font(.system(size: 68))
                .foregroundColor(.white.opacity(0.92))
            Image(systemName: "checkmark")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(Color(red: 0.20, green: 0.52, blue: 0.96))
                .offset(y: 4)
        }
    }
}

struct HistoryView: View {
    @Binding var selectedTab: Int
    @State private var sessions: [Session] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isEditing = false
    @State private var deleteConfirmation: Session?

    private let deviceId: String = UIDevice.current.identifierForVendor?.uuidString ?? "simulator"
    private let api = APIClient.shared
    private let historyBackground = Color(red: 0.965, green: 0.976, blue: 0.984)

    private var draftSessions: [Session] { sessions.filter { $0.type == "draft" } }
    private var reviewSessions: [Session] { sessions.filter { $0.type == "review" } }

    var body: some View {
        NavigationView {
            ZStack {
                historyBackground.ignoresSafeArea()

                Group {
                    if isLoading {
                        ProgressView("加载中…")
                    } else if sessions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "clock.badge.questionmark")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("暂无历史记录，完成合同操作后记录会出现在这里")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                if !draftSessions.isEmpty {
                                    sectionHeader("合同生成")
                                    ForEach(draftSessions) { session in
                                        HistoryCard(session: session, isEditing: isEditing) {
                                            deleteSessionById(session.id)
                                        }
                                    }
                                }
                                if !reviewSessions.isEmpty {
                                    sectionHeader("合同审查")
                                    ForEach(reviewSessions) { session in
                                        HistoryCard(session: session, isEditing: isEditing) {
                                            deleteSessionById(session.id)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }
            }
            .navigationTitle("历史记录")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        selectedTab = 0
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(DraftStyle.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !sessions.isEmpty {
                        Button(isEditing ? "完成" : "管理") {
                            withAnimation { isEditing.toggle() }
                        }
                    }
                }
            }
            .refreshable { await loadSessions() }
            .task { await loadSessions() }
            .alert("删除记录", isPresented: .init(
                get: { deleteConfirmation != nil },
                set: { if !$0 { deleteConfirmation = nil } }
            )) {
                Button("取消", role: .cancel) { deleteConfirmation = nil }
                Button("删除", role: .destructive) {
                    if let session = deleteConfirmation {
                        Task { await deleteSession(session) }
                    }
                }
            } message: {
                Text("确定要删除这条记录吗？此操作不可撤销。")
            }
        }
    }

    private func loadSessions() async {
        isLoading = true
        errorMessage = nil
        do {
            // 不传 type → 后端返回 draft + review 全部会话
            sessions = try await api.getSessions(deviceId: deviceId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteSessionById(_ id: String) {
        guard let session = sessions.first(where: { $0.id == id }) else { return }
        Task { await deleteSession(session) }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(DraftStyle.primary.opacity(0.7))
            .padding(.leading, 4)
    }

    private func deleteSessions(at offsets: IndexSet) async {
        let targets = offsets.compactMap { index in
            sessions.indices.contains(index) ? sessions[index] : nil
        }
        guard !targets.isEmpty else { return }

        withAnimation {
            sessions.remove(atOffsets: offsets)
        }

        for session in targets {
            do {
                try await api.deleteSession(id: session.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        await loadSessions()
    }

    private func deleteSession(_ session: Session) async {
        do {
            try await api.deleteSession(id: session.id)
            await loadSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
        deleteConfirmation = nil
    }
}

// MARK: - 历史卡片

struct HistoryCard: View {
    let session: Session
    let isEditing: Bool
    let onDelete: () -> Void

    private var isReview: Bool { session.type == "review" }
    private var typeLabel: String { isReview ? "合同审查" : "合同生成" }

    var body: some View {
        Group {
            if isReview {
                ReviewHistoryRow(session: session, typeLabel: typeLabel)
            } else {
                NavigationLink(destination: DraftFlowView(restoreSessionId: session.id)) {
                    HistoryRow(session: session, typeLabel: typeLabel)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        )
        .overlay(alignment: .topTrailing) {
            if isEditing {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                        .background(Circle().fill(.white))
                }
                .offset(x: 6, y: -6)
            }
        }
    }
}

struct HistoryRow: View {
    let session: Session
    let typeLabel: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.type == "review" ? "magnifyingglass.circle.fill" : "doc.text.fill")
                .font(.title2)
                .foregroundColor(DraftStyle.primary.opacity(0.7))

            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(formatDate(session.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(typeLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                }
            }

            Spacer()

            if session.type != "review" {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) {
            let df = DateFormatter()
            df.dateFormat = "MM/dd HH:mm"
            return df.string(from: date)
        }
        return iso
    }
}

struct ReviewHistoryRow: View {
    let session: Session
    let typeLabel: String

    var body: some View {
        NavigationLink(destination: ReviewFlowView(restoreSessionId: session.id)) {
            HistoryRow(session: session, typeLabel: typeLabel)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("0.1.0")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    QiHeLogoMark()
                        .frame(width: 22, height: 22)
                }
            }
        }
    }
}

struct ReviewFlowView: View {
    @StateObject private var vm: ReviewFlowViewModel

    init(restoreSessionId: String? = nil) {
        if let sid = restoreSessionId {
            _vm = StateObject(wrappedValue: ReviewFlowViewModel(restoreSessionId: sid))
        } else {
            _vm = StateObject(wrappedValue: ReviewFlowViewModel())
        }
    }

    var body: some View {
        ZStack {
            DraftBackground()

            switch vm.currentStep {
            case .input:
                inputPage
            case .analyzing:
                analyzingPage
            case .result:
                resultPage
            }
        }
        .navigationTitle("合同审查")
        .navigationBarTitleDisplayMode(.inline)
        .alert("出错了", isPresented: $vm.showError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(vm.errorMessage)
        }
        .sheet(isPresented: $vm.showCamera) {
            CameraPicker { image in vm.processImage(image) }
        }
        .sheet(isPresented: $vm.showPhotoPicker) {
            PhotoPicker { image in vm.processImage(image) }
        }
        .fileImporter(
            isPresented: $vm.showFileImporter,
            allowedContentTypes: [
                .pdf,
                .plainText,
                UTType("org.openxmlformats.wordprocessingml.document")!,
            ]
        ) { result in
            switch result {
            case .success(let url):
                vm.importFile(url)
            case .failure(let error):
                vm.errorMessage = error.localizedDescription
                vm.showError = true
            }
        }
    }

    // MARK: - 输入页

    private var inputPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Logo 栏
                HStack(spacing: 10) {
                    QiHeLogoMark().frame(width: 28, height: 28)
                    Text("合同审查")
                        .font(.title3.weight(.bold))
                        .foregroundColor(DraftStyle.primary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // 文本框
                VStack(alignment: .leading, spacing: 8) {
                    Text("合同文本")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)

                    // OCR 入口按钮行
                    HStack(spacing: 12) {
                        Button {
                            vm.showCamera = true
                        } label: {
                            Label("拍照识别", systemImage: "camera.fill")
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(DraftStyle.primary.opacity(0.08))
                                .foregroundColor(DraftStyle.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            vm.showPhotoPicker = true
                        } label: {
                            Label("相册选择", systemImage: "photo.on.rectangle")
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(DraftStyle.primary.opacity(0.08))
                                .foregroundColor(DraftStyle.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            vm.showFileImporter = true
                        } label: {
                            Label("文件导入", systemImage: "doc.fill")
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(DraftStyle.primary.opacity(0.08))
                                .foregroundColor(DraftStyle.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        if vm.isRecognizingText {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("识别中…")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }

                    TextEditor(text: $vm.contractText)
                        .font(.system(size: 15))
                        .frame(minHeight: 200)
                        .padding(10)
                        .background(Color(red: 0.941, green: 0.953, blue: 0.969))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if vm.contractText.count > 4500 {
                        Text("合同文本较长（\(vm.contractText.count)字），审查可能需要更长时间")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)

                // 立场选择
                VStack(alignment: .leading, spacing: 10) {
                    Text("我是")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    HStack(spacing: 10) {
                        roleButton("我是租客", value: "tenant")
                        roleButton("我是房东", value: "landlord")
                        roleButton("中立视角", value: "neutral")
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    Task { await vm.startReview() }
                } label: {
                    Text("开始审查")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            vm.contractText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.gray.opacity(0.35)
                                : DraftStyle.primary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(vm.contractText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.userRole.isEmpty || vm.isAnalyzing)

                if vm.userRole.isEmpty {
                    Text("请先选择您的身份")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    private func roleButton(_ title: String, value: String) -> some View {
        let isSelected = vm.userRole == value
        return Button {
            vm.userRole = value
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? DraftStyle.primary : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 分析中页

    private var analyzingPage: some View {
        VStack {
            Spacer()
            VStack(spacing: 14) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(DraftStyle.primary)
                Text("正在分析合同条款…")
                    .font(.headline)
                Text("识别条款 → 检查风险 → 生成报告")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(32)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 结果页

    private var resultPage: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let summary = vm.summary {
                        summaryCard(summary)
                    }
                    ForEach(vm.risks) { risk in
                        RiskCardView(risk: risk)
                    }
                    Spacer().frame(height: 80)
                }
                .padding()
            }

            // 底部重新审查按钮
            VStack {
                Button {
                    vm.reset()
                } label: {
                    Text("重新审查")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(DraftStyle.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(.ultraThinMaterial)
        }
    }

    private func summaryCard(_ summary: ReviewSummary) -> some View {
        VStack(spacing: 12) {
            HStack {
                let isValidContract = !(summary.totalRisks == 0 && summary.suggestion.contains("未检测到"))
                Image(systemName: isValidContract ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(isValidContract ? .green : .orange)
                Text(isValidContract ? "审查完成" : "无法识别")
                    .font(.title3.weight(.bold))
                Spacer()
            }
            Text(summary.suggestion)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 16) {
                Label("\(summary.redCount) 高风险", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Label("\(summary.yellowCount) 需确认", systemImage: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                Label("\(summary.greenCount) 无问题", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            .font(.caption)
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }
}

// MARK: - 风险卡片

struct RiskCardView: View {
    let risk: RiskCard

    private var levelColor: Color {
        switch risk.level {
        case "red": return .red
        case "yellow": return .orange
        case "green": return .green
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题行
            HStack(spacing: 8) {
                Circle().fill(levelColor).frame(width: 8, height: 8)
                Text(risk.title)
                    .font(.headline)
                Spacer()
                if risk.needsLawyer {
                    Label("建议咨询律师", systemImage: "exclamationmark.shield")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            // 原文引用
            Text("📄 原文")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text(risk.quote)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // 白话解释
            Text("💡 为什么有风险")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text(risk.plainExplanation)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 建议改法
            Text("✏️ 建议修改")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text(risk.suggestedRevision)
                .font(.subheadline)
                .foregroundColor(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }
}

// MARK: - 首页聊天卡片

struct HomeInputBar: View {
    @State private var inputText: String = ""
    @State private var navigateToChat = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("描述你的合同需求或法律问题…", text: $inputText)
                    .font(.system(size: 14))
                    .submitLabel(.send)
                    .onSubmit { if !inputText.trimmingCharacters(in: .whitespaces).isEmpty { navigateToChat = true } }

                Button {
                    if !inputText.trimmingCharacters(in: .whitespaces).isEmpty {
                        navigateToChat = true
                    }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.gray.opacity(0.35)
                                : Color(red: 0.09, green: 0.23, blue: 0.37)
                        )
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)

            // Prompt 快捷入口
            HStack(spacing: 8) {
                Text("试试问").font(.caption).foregroundColor(.secondary)
                HomePromptChip(text: "租房押金怎么退？") { inputText = "租房押金怎么退？" }
                HomePromptChip(text: "违约金一般多少？") { inputText = "违约金一般多少？" }
                Spacer()
            }
            .padding(.top, 10)
            .padding(.leading, 4)

            // 隐藏的 NavigationLink
            NavigationLink(
                destination: HomeChatView(initialMessage: inputText.trimmingCharacters(in: .whitespaces)),
                isActive: $navigateToChat
            ) { EmptyView() }
        }
    }
}

struct HomePromptChip: View {
    let text: String
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            Text(text)
                .font(.caption2.weight(.medium))
                .foregroundColor(Color(red: 0.09, green: 0.23, blue: 0.37))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(red: 0.09, green: 0.23, blue: 0.37).opacity(0.06))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 相机拾取器

struct CameraPicker: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (UIImage) -> Void
        init(onPick: @escaping (UIImage) -> Void) { self.onPick = onPick }
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage { onPick(image) }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - 相册拾取器

struct PhotoPicker: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage) -> Void
        init(onPick: @escaping (UIImage) -> Void) { self.onPick = onPick }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first else { return }
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage {
                    DispatchQueue.main.async { self.onPick(image) }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
