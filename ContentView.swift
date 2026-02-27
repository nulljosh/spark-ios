import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "flame")
                }
                .tag(0)

            CreateView()
                .tabItem {
                    Label("Create", systemImage: "plus.circle")
                }
                .tag(1)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(2)
        }
        .tint(Color(hex: "0071e3"))
    }
}

struct FeedView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(0..<5) { i in
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .frame(height: 120)
                            .overlay(
                                Text("Idea \(i + 1)")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            )
                    }
                }
                .padding()
            }
            .navigationTitle("Spark")
        }
    }
}

struct CreateView: View {
    @State private var title = ""
    @State private var body = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("New Idea") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $body, axis: .vertical)
                        .lineLimit(4...8)
                }
                Section {
                    Button("Post") {}
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
            }
            .navigationTitle("Create")
        }
    }
}

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 60, height: 60)
                        VStack(alignment: .leading) {
                            Text("Username")
                                .font(.headline)
                            Text("0 posts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Settings") {
                    Label("Account", systemImage: "person")
                    Label("Notifications", systemImage: "bell")
                    Label("Sign Out", systemImage: "arrow.right.square")
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Profile")
        }
    }
}

extension Color {
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
}
