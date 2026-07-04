import SwiftUI

// MARK: - 聊天气泡

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(
                        message.isUser
                        ? Color.purple
                        : Color(.systemGray5)
                    )
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(16)

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
                        .fill(Color.gray)
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
            .background(Color(.systemGray5))
            .cornerRadius(16)

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
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(field.value ?? "待填写")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(field.isMissing ? .gray : .primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(field.isMissing ? Color(.systemGray6) : Color.purple.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(field.isMissing ? Color.gray.opacity(0.3) : Color.purple.opacity(0.4), lineWidth: 1)
        )
    }
}
