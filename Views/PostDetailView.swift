import SwiftUI

struct PostDetailView: View {
    @Environment(AppState.self) private var appState
    let post: Post

    private var currentPost: Post {
        appState.posts.first(where: { $0.id == post.id }) ?? post
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    CategoryBadge(category: currentPost.category)
                    Spacer()
                    if let createdAt = currentPost.createdAt {
                        Text(relativeDate(createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(currentPost.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle")
                        .foregroundStyle(.secondary)
                    Text(currentPost.author?.username ?? "Unknown")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Text(currentPost.content)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack(spacing: 14) {
                    VoteButton(label: "up", icon: "arrow.up", postId: currentPost.id)
                    Text("\(currentPost.score)")
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText(value: Double(currentPost.score)))
                        .animation(.spring(duration: 0.3), value: currentPost.score)
                    VoteButton(label: "down", icon: "arrow.down", postId: currentPost.id)
                    Spacer()
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: "\(currentPost.title)\n\n\(currentPost.content)") {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt
    }()

    private static let isoFormatterNoFraction: ISO8601DateFormatter = {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        return fmt
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt
    }()

    private func relativeDate(_ iso: String) -> String {
        guard let date = Self.isoFormatter.date(from: iso)
            ?? Self.isoFormatterNoFraction.date(from: iso) else { return "" }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}
