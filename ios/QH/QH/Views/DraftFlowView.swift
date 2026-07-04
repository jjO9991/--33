import SwiftUI

// MARK: - 消息模型

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let role: String          // "user" / "assistant" / "system"
    let content: String
    let createdAt: Date

    var isUser: Bool { role == "user" }
}

// MARK: - 字段状态

struct FieldStatus: Identifiable {
    let id = UUID()
    let key: String
    let label: String
    var value: String?

    var isMissing: Bool {
        guard let v = value else { return true }
        return v.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - 拟定合同流

struct DraftFlowView: View {
    let restoreSessionId: String?

    @StateObject private var vm: DraftFlowViewModel
    @State private var expandedCategories: Set<String> = []
    @State private var showNewSessionAlert = false

    init(restoreSessionId: String? = nil) {
        self.restoreSessionId = restoreSessionId
        _vm = StateObject(wrappedValue: DraftFlowViewModel(restoreSessionId: restoreSessionId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 可收起气泡
            collapsibleBubble

            // 聊天消息列表
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
                .onChange(of: vm.messages.count) { _, _ in
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
                Button {
                    showNewSessionAlert = true
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
        }
        .alert("开启新对话？", isPresented: $showNewSessionAlert) {
            Button("取消", role: .cancel) {}
            Button("确定", role: .destructive) {
                vm.startNewSession()
            }
        } message: {
            Text("当前对话记录将被保留，你也可以在历史记录中查看。")
        }
        .alert("出错了", isPresented: $vm.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(vm.errorMessage)
        }
    }

    // MARK: - 可收起气泡

    private var collapsibleBubble: some View {
        VStack(spacing: 0) {
            // 气泡头部 — 点击展开/收起
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    vm.isBubbleExpanded.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.purple)
                        .font(.caption)

                    Text("合同信息总览")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("（已填 \(vm.filledCount)/\(vm.totalCount)）")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Image(systemName: vm.isBubbleExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
            }

            // 气泡展开内容
            if vm.isBubbleExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 12) {
                            // 按分类展示
                            ForEach(DraftFlowViewModel.fieldCategories, id: \.name) { category in
                                categorySection(category)
                            }

                            // 底部按钮
                            HStack(spacing: 12) {
                                Button(action: vm.generateTemplate) {
                                    Label("生成模板", systemImage: "doc.text")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.purple.opacity(0.1))
                                        .cornerRadius(8)
                                }

                                Button(action: vm.submitFromBubble) {
                                    Label("提交", systemImage: "paperplane.fill")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.purple)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(12)
                    }
                    .frame(maxHeight: 260)
                }
                .background(Color(.systemBackground))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(10)
        .padding(.horizontal, 8)
        .padding(.top, 6)
    }

    // MARK: - 分类区块

    private func categorySection(_ category: FieldCategoryInfo) -> some View {
        let catFilled = vm.categoryFilledCount(category)
        let catTotal = category.keys.count
        let allFilled = catFilled == catTotal
        let isExpanded = expandedCategories.contains(category.name)

        return VStack(alignment: .leading, spacing: 6) {
            // 分类头部
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedCategories.remove(category.name)
                    } else {
                        expandedCategories.insert(category.name)
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: category.icon)
                        .font(.caption)
                        .foregroundColor(allFilled ? .green : .orange)

                    Text(category.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(catFilled)/\(catTotal)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            // 展开的子字段
            if isExpanded {
                VStack(spacing: 6) {
                    ForEach(category.keys, id: \.self) { key in
                        editableFieldRow(key: key)
                    }
                }
                .padding(.leading, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 可编辑字段行

    private func editableFieldRow(key: String) -> some View {
        guard let field = vm.fields.first(where: { $0.key == key }) else {
            return AnyView(EmptyView())
        }

        return AnyView(
            HStack(spacing: 8) {
                Text(field.label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)

                TextField("填写\(field.label)", text: vm.fieldBinding(for: key))
                    .font(.caption)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
        )
    }

    // MARK: - 输入栏

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("输入信息，或在上方面板填写后提交…", text: $vm.inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
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
