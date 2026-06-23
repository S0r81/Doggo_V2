//
//  CoachChatView.swift
//  Doggo_V2
//
//  Chat mode for the AI Coach: a persistent conversational thread. Every turn
//  goes through CoachChatEngine -> container.aiClient (the same path the report
//  uses), and carries the shared data grounding + the user's "What Coach knows"
//  context, so the Coach reasons from the user's real data without reminders.
//

import SwiftUI
import SwiftData

struct CoachChatView: View {
    let container: AppContainer
    let sessions: [WorkoutSession]
    let threadID: UUID

    @Environment(\.modelContext) private var modelContext
    @AppStorage("userTheme") private var userTheme: AppTheme = .light

    @Query private var messages: [CoachMessage]
    @Query private var profiles: [UserProfile]
    @Query private var contextItems: [CoachContextItem]

    @State private var input = ""
    @State private var isThinking = false
    @State private var errorText: String?
    @FocusState private var inputFocused: Bool

    init(container: AppContainer, sessions: [WorkoutSession], threadID: UUID) {
        self.container = container
        self.sessions = sessions
        self.threadID = threadID
        _messages = Query(
            filter: #Predicate<CoachMessage> { $0.threadID == threadID },
            sort: \CoachMessage.timestamp, order: .forward
        )
    }

    /// The seed quick-actions — they prefill *and send* a starting prompt, but
    /// the user can always type freely instead.
    private let quickActions: [(label: String, icon: String, prompt: String)] = [
        ("Reset my targets", "target", "Help me reset my nutrition and training targets based on my recent data."),
        ("Design a program", "calendar", "Design a new training program for me that fits my schedule and goals."),
        ("Plan my meals", "fork.knife", "Plan my meals for today around my macro targets."),
        ("Build a workout", "dumbbell", "Build me a workout for today based on what I've trained recently.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.md) {
                        if messages.isEmpty {
                            emptyState
                        } else {
                            ForEach(messages) { message in
                                messageBubble(message).id(message.id)
                            }
                        }
                        if isThinking { thinkingRow.id("thinking") }
                        if let errorText { errorRow(errorText).id("error") }
                    }
                    .padding(Spacing.lg)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in scrollToEnd(proxy) }
                .onChange(of: isThinking) { _, _ in scrollToEnd(proxy) }
            }

            inputBar
        }
        .background(Color.background(for: userTheme).ignoresSafeArea())
        .toolbar {
            // Done affordance — escape hatch for the stuck-keyboard class of bug.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { inputFocused = false }
            }
        }
    }

    // MARK: - Empty state + quick actions

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accent(for: userTheme))
                Text("Talk to your Coach")
                    .font(.title3.bold())
                Text("I already know your training, nutrition, and the notes you've shared. Ask me anything, or start here:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            CoachQuickActionChips(items: quickActions.map { ($0.label, $0.icon) }) { index in
                send(quickActions[index].prompt)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.xl)
    }

    // MARK: - Bubbles

    @ViewBuilder
    private func messageBubble(_ message: CoachMessage) -> some View {
        let isUser = message.role == .user
        HStack {
            if isUser { Spacer(minLength: Spacing.xl) }
            Text(LocalizedStringKey(message.text))
                .padding(Spacing.md)
                .background(
                    isUser ? Color.accent(for: userTheme).opacity(0.18)
                           : Color.cardSurface(for: userTheme),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
                .textSelection(.enabled)
            if !isUser { Spacer(minLength: Spacing.xl) }
        }
        .accessibilityLabel(isUser ? "You said" : "Coach said")
    }

    private var thinkingRow: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView().controlSize(.small)
            Text("Coach is thinking…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
    }

    private func errorRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(text).font(.subheadline)
                Button("Try again") { retryLast() }
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Message Coach…", text: $input, axis: .vertical)
                .lineLimit(1...5)
                .focused($inputFocused)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.cardSurface(for: userTheme), in: Capsule())
                .submitLabel(.send)
                .onSubmit { send(input) }

            Button {
                send(input)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(canSend ? Color.accent(for: userTheme) : .secondary)
            }
            .disabled(!canSend)
            .accessibilityLabel("Send message")
        }
        .padding(Spacing.md)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking
    }

    // MARK: - Send

    private func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }

        errorText = nil
        input = ""
        inputFocused = false

        // Persist the user's turn immediately so it survives even if the
        // request fails or the app is backgrounded.
        let userMessage = CoachMessage(role: .user, text: text, threadID: threadID)
        modelContext.insert(userMessage)
        try? modelContext.save()

        // Snapshot history (prior turns) for the prompt; the engine windows it.
        let history = messages.filter { $0.id != userMessage.id }
        let profile = profiles.first
        let items = contextItems

        isThinking = true
        Task {
            do {
                let reply = try await CoachChatEngine.reply(
                    to: text,
                    history: history,
                    sessions: sessions,
                    profile: profile,
                    contextItems: items,
                    client: container.aiClient
                )
                await MainActor.run {
                    let assistant = CoachMessage(role: .assistant, text: reply, threadID: threadID)
                    modelContext.insert(assistant)
                    try? modelContext.save()
                    isThinking = false
                }
            } catch {
                await MainActor.run {
                    isThinking = false
                    errorText = error.localizedDescription
                    HapticManager.shared.notification(type: .warning)
                }
            }
        }
    }

    private func retryLast() {
        // Re-send the most recent user message (its reply never arrived).
        guard let lastUser = messages.last(where: { $0.role == .user }) else { return }
        errorText = nil
        send(lastUser.text)
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if isThinking { proxy.scrollTo("thinking", anchor: .bottom) }
            else if errorText != nil { proxy.scrollTo("error", anchor: .bottom) }
            else if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }
}

// MARK: - Quick-action chips

/// Simple wrapping row of tappable chips.
private struct CoachQuickActionChips: View {
    let items: [(String, String)]   // (label, icon)
    let onTap: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button { onTap(index) } label: {
                    Label(item.0, systemImage: item.1)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
