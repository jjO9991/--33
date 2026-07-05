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
        ZStack {
            DraftBackground()

            VStack(spacing: 0) {
                draftHeader
                collapsibleBubble

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
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                    }
                    .onChange(of: vm.messages.count) { _, _ in
                        if let last = vm.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                inputBar
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tint(DraftStyle.primary)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNewSessionAlert = true
                } label: {
                    Label("新对话", systemImage: "plus")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(DraftStyle.primary)
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

    private var draftHeader: some View {
        HStack(spacing: 10) {
            QiHeLogoMark()
                .frame(width: 28, height: 28)
            Text("合同生成")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(DraftStyle.primary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
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
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(DraftStyle.primary)
                        .font(.subheadline)

                    Text("合同信息总览")
                        .font(.system(size: 15, weight: .semibold))
                        .fontWeight(.semibold)
                        .foregroundColor(DraftStyle.primary)

                    Text("（已填 \(vm.filledCount)/\(vm.totalCount)）")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Image(systemName: vm.isBubbleExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(DraftStyle.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, vm.isBubbleExpanded ? 12 : 9)
                .background(.white)
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
                                        .padding(.vertical, 10)
                                        .background(DraftStyle.primary.opacity(0.08))
                                        .foregroundColor(DraftStyle.primary)
                                        .clipShape(Capsule())
                                }

                                Button(action: vm.submitFromBubble) {
                                    Label("提交", systemImage: "paperplane.fill")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(DraftStyle.primary)
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(12)
                    }
                    .frame(maxHeight: 260)
                }
                .background(.white)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.white)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
        .padding(.horizontal, 16)
        .padding(.top, 2)
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
                    Image(systemName: allFilled ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13))
                        .foregroundColor(allFilled ? .green : .gray.opacity(0.5))

                    Text(category.name)
                        .font(.system(size: 14))
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
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)

                TextField("填写\(field.label)", text: vm.fieldBinding(for: key))
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.96, green: 0.98, blue: 0.99))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
        )
    }

    // MARK: - 输入栏

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("输入信息，或在上方面板填写后提交…", text: $vm.inputText, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(1...3)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(red: 0.96, green: 0.98, blue: 0.99))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .submitLabel(.send)
                .onSubmit { vm.sendMessage() }

            Button(action: vm.sendMessage) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(vm.inputText.isEmpty ? Color.gray.opacity(0.35) : DraftStyle.primary)
                    .clipShape(Circle())
            }
            .disabled(vm.inputText.isEmpty || vm.isSending)
        }
        .padding(14)
        .background(.white.opacity(0.96))
    }
}

enum DraftStyle {
    static let primary = Color(red: 0.09, green: 0.23, blue: 0.37)
}

struct DraftBackground: View {
    var body: some View {
        Color(red: 0.965, green: 0.976, blue: 0.984)
            .ignoresSafeArea()
    }
}
