import SwiftUI

// MARK: - 聊天气泡

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if message.isUser {
                    Text(message.content)
                        .font(.system(size: 16))
                        .lineSpacing(3)
                        .padding(12)
                        .background(DraftStyle.primary)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
                } else {
                    Text((try? AttributedString(markdown: message.content)) ?? AttributedString(message.content))
                        .font(.system(size: 16))
                        .lineSpacing(3)
                        .padding(12)
                        .background(Color.white)
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                }

                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !message.isUser { Spacer(minLength: 40) }
        }
    }
}

// MARK: - 输入中指示

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(DraftStyle.primary)
                        .frame(width: 6, height: 6)
                        .scaleEffect(animating ? 1 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(i) * 0.2),
                            value: animating
                        )
                }
            }
            .padding(12)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)

            Spacer(minLength: 40)
        }
        .onAppear { animating = true }
    }
}

// MARK: - 字段 chip

struct FieldChip: View {
    let field: FieldStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(field.label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(field.value ?? "待填写")
                .font(.system(size: 12, weight: .medium))
                .fontWeight(.medium)
                .foregroundColor(field.isMissing ? .gray : .primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(field.isMissing ? Color(.systemGray6) : DraftStyle.primary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(field.isMissing ? Color.gray.opacity(0.3) : DraftStyle.primary.opacity(0.35), lineWidth: 1)
        )
    }
}
