import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
            HistoryView()
                .tabItem {
                    Label("历史", systemImage: "clock.fill")
                }
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
        .accentColor(.purple)
    }
}

struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("契合")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("房屋租赁合同 AI 助手")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                VStack(spacing: 16) {
                    NavigationLink(destination: DraftFlowView()) {
                        Label("拟定合同", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    NavigationLink(destination: ReviewFlowView()) {
                        Label("审核合同", systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                Spacer()

                Text("⚡ 平均 20 秒完成一份合同")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

struct HistoryView: View {
    @State private var sessions: [Session] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isEditing = false
    @State private var deleteConfirmation: Session?

    private let deviceId: String = UIDevice.current.identifierForVendor?.uuidString ?? "simulator"
    private let api = APIClient.shared

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("加载中…")
                } else if sessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("暂无历史记录")
                            .foregroundColor(.secondary)
                        Text("开始拟定合同后，记录会出现在这里")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(sessions) { session in
                            NavigationLink(destination: DraftFlowView(restoreSessionId: session.id)) {
                                HistoryRow(session: session)
                            }
                        }
                        .onDelete { indexSet in
                            Task { await deleteSessions(at: indexSet) }
                        }
                    }
                }
            }
            .navigationTitle("历史记录")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !sessions.isEmpty {
                        Button(isEditing ? "完成" : "管理") {
                            withAnimation { isEditing.toggle() }
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(isEditing ? .active : .inactive))
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
            sessions = try await api.getSessions(deviceId: deviceId, type: "draft")
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteSessions(at offsets: IndexSet) async {
        for index in offsets {
            let session = sessions[index]
            do {
                try await api.deleteSession(id: session.id)
                await loadSessions()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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

// MARK: - 历史记录行

struct HistoryRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.title3)
                .foregroundColor(.purple)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(formatDate(session.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
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

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "created", "processing": return .orange
        case "completed": return .green
        case "failed": return .red
        default: return .secondary
        }
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
        }
    }
}

struct ReviewFlowView: View {
    var body: some View {
        Text("审核合同工作区")
            .navigationTitle("审核合同")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
