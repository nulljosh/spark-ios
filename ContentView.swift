import SwiftUI

// MARK: - Root

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem { Label("Feed", systemImage: "flame") }
                .tag(0)

            CreateView(selectedTab: $selectedTab)
                .tabItem { Label("Create", systemImage: "plus.circle") }
                .tag(1)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
                .tag(2)
        }
        .tint(.accent)
        .sheet(isPresented: $appState.showAuth) {
            AuthSheet()
        }
    }
}

// MARK: - Feed

struct FeedView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            Group {
                if appState.posts.isEmpty && !appState.isLoading {
                    ContentUnavailableView("No posts yet", systemImage: "flame", description: Text("Be the first to share an idea."))
                } else {
                    List(appState.posts) { post in
                        PostCard(post: post)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .refreshable { await appState.loadPosts() }
                }
            }
            .navigationTitle("Spark")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    AuthButton()
                }
            }
            .task { await appState.loadPosts() }
        }
    }
}

struct PostCard: View {
    @Environment(AppState.self) private var appState
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CategoryBadge(category: post.category)
                Spacer()
                if let author = post.author {
                    Text(author.username)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(post.title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(post.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack(spacing: 12) {
                VoteButton(label: "up", icon: "arrow.up", postId: post.id)
                Text("\(post.score)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.primary)
                VoteButton(label: "down", icon: "arrow.down", postId: post.id)
                Spacer()
                if let date = post.createdAt {
                    Text(relativeDate(date))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
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

struct VoteButton: View {
    @Environment(AppState.self) private var appState
    let label: String
    let icon: String
    let postId: String

    var body: some View {
        Button {
            Task { await appState.vote(postId: postId, type: label) }
        } label: {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(appState.isLoggedIn ? .accent : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(!appState.isLoggedIn)
    }
}

struct CategoryBadge: View {
    let category: String

    var body: some View {
        Text(category)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.accent.opacity(0.15), in: Capsule())
            .foregroundStyle(.accent)
    }
}

// MARK: - Create

struct CreateView: View {
    @Environment(AppState.self) private var appState
    @Binding var selectedTab: Int

    @State private var title = ""
    @State private var content = ""
    @State private var category = "General"
    @State private var isPosting = false
    @State private var errorMsg: String?
    @State private var showSuccess = false

    let categories = ["General", "Tech", "Science", "Art", "Business", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Idea") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $content, axis: .vertical)
                        .lineLimit(4...8)
                }
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                }
                if let err = errorMsg {
                    Section {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                Section {
                    Button(action: post) {
                        if isPosting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Post")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canPost)
                }
            }
            .navigationTitle("Create")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    AuthButton()
                }
            }
            .alert("Posted!", isPresented: $showSuccess) {
                Button("OK") { selectedTab = 0 }
            }
            .overlay {
                if !appState.isLoggedIn {
                    ContentUnavailableView {
                        Label("Sign in to post", systemImage: "lock")
                    } description: {
                        Text("Create an account or log in to share ideas.")
                    } actions: {
                        Button("Sign In") { appState.showAuth = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private var canPost: Bool {
        appState.isLoggedIn && !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !content.trimmingCharacters(in: .whitespaces).isEmpty && !isPosting
    }

    private func post() {
        isPosting = true
        errorMsg = nil
        Task {
            do {
                try await appState.createPost(title: title, content: content, category: category)
                title = ""
                content = ""
                category = "General"
                showSuccess = true
            } catch {
                errorMsg = error.localizedDescription
            }
            isPosting = false
        }
    }
}

// MARK: - Profile

struct ProfileView: View {
    @Environment(AppState.self) private var appState

    var myPosts: [Post] {
        guard let username = appState.user?.username else { return [] }
        return appState.posts.filter { $0.author?.username == username }
    }

    var body: some View {
        NavigationStack {
            List {
                if appState.isLoggedIn, let user = appState.user {
                    Section {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color.accent.opacity(0.15))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text(String(user.username.prefix(1)).uppercased())
                                        .font(.title2.bold())
                                        .foregroundStyle(.accent)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.username)
                                    .font(.headline)
                                Text("\(myPosts.count) post\(myPosts.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if !myPosts.isEmpty {
                        Section("Your Posts") {
                            ForEach(myPosts) { post in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(post.title)
                                        .font(.subheadline.weight(.medium))
                                    HStack {
                                        CategoryBadge(category: post.category)
                                        Spacer()
                                        Label("\(post.score)", systemImage: "arrow.up")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            appState.logout()
                        } label: {
                            Label("Sign Out", systemImage: "arrow.right.square")
                        }
                    }
                } else {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("Not signed in")
                                .font(.headline)
                            Button("Sign In / Register") {
                                appState.showAuth = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.accent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Profile")
        }
    }
}

// MARK: - Auth Sheet

struct AuthSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var tab = 0
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Picker("Mode", selection: $tab) {
                    Text("Sign In").tag(0)
                    Text("Register").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                VStack(spacing: 14) {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)

                    if tab == 1 {
                        TextField("Email (optional)", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                    }

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                }

                if let err = appState.error {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Button(action: submit) {
                    if appState.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(tab == 0 ? "Sign In" : "Create Account")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.accent)
                .controlSize(.large)
                .disabled(!canSubmit)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle(tab == 0 ? "Sign In" : "Register")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        appState.error = nil
                        dismiss()
                    }
                }
            }
        }
    }

    private var canSubmit: Bool {
        !username.isEmpty && !password.isEmpty && !appState.isLoading
    }

    private func submit() {
        Task {
            if tab == 0 {
                await appState.login(username: username, password: password)
            } else {
                await appState.register(username: username, email: email.isEmpty ? nil : email, password: password)
            }
        }
    }
}

// MARK: - Auth Toolbar Button

struct AuthButton: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.isLoggedIn {
            Button {
                appState.logout()
            } label: {
                Image(systemName: "person.fill.checkmark")
                    .foregroundStyle(.accent)
            }
        } else {
            Button("Sign In") {
                appState.showAuth = true
            }
            .tint(.accent)
        }
    }
}

// MARK: - Color Extension

extension Color {
    static let accent = Color(hex: "0071e3")

    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
