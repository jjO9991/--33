import SwiftUI

// MARK: - 消息模型

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let role: String          // "user" / "assistant" / "system"
    let content: String
    let createdAt: Date

    var isUser: Bool { role == "user" }
}

// MARK: - 字段面板

struct FieldStatus: Identifiable {
    let id = UUID()
    let key: String
    let label: String
    var value: String?
    var isMissing: Bool { value == nil || value?.isEmpty == true }
}

// MARK: - 拟定合同流

struct DraftFlowView: View {
    @StateObject private var vm = DraftFlowViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // 顶部完整度进度
            completenessBar

            // 字段面板（可折叠）
            if vm.showFieldPanel {
                fieldPanel
            }

            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(vm.messages) { msg in
                            ChatBubble(message: msg)
                        }
                        if vm.isSending {
                            TypingIndicator()
                        }
                    }
                    .padding()
                }
                .onChange(of: vm.messages.count) { _ in
                    if let last = vm.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // 输入栏
            inputBar
        }
        .navigationTitle("拟定合同")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(vm.showFieldPanel ? "收起字段" : "查看字段") {
                    withAnimation { vm.showFieldPanel.toggle() }
                }
            }
        }
        .alert("出错了", isPresented: $vm.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(vm.errorMessage)
        }
    }

    // MARK: - 子视图

    private var completenessBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("完整度")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(vm.completeness * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
            }
            ProgressView(value: vm.completeness)
                .tint(.purple)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    private var fieldPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("已收集字段")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.fields) { field in
                        FieldChip(field: field)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("说点什么，比如'出租方是中国银行'", text: $vm.inputText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit { vm.sendMessage() }

            Button(action: vm.sendMessage) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(vm.inputText.isEmpty ? .gray : .purple)
            }
            .disabled(vm.inputText.isEmpty || vm.isSending)
        }
        .padding()
        .background(Color(.systemGray6))
    }
}
