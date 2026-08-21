import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: NewsStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var searchText = ""
    @State private var showingFavorites = false
    @State private var showingSettings = false

    private var filteredItems: [NewsItem] {
        store.items.filter { item in
            let matchesSearch = searchText.isEmpty || item.title.localizedCaseInsensitiveContains(searchText) || item.source.localizedCaseInsensitiveContains(searchText)
            let matchesKeywords = settingsStore.settings.keywords.isEmpty || settingsStore.settings.keywords.contains { item.title.localizedCaseInsensitiveContains($0) }
            return matchesSearch && matchesKeywords && (!showingFavorites || item.isFavorite)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredItems.isEmpty {
                    ContentUnavailableView("暂无热点", systemImage: "newspaper", description: Text("下拉刷新或检查网络连接"))
                } else {
                    List(filteredItems) { item in
                        NavigationLink {
                            NewsDetailView(item: item)
                                .task { await store.markRead(item) }
                        } label: {
                            NewsRow(item: item)
                        }
                        .swipeActions(edge: .trailing) {
                            Button { Task { await store.toggleFavorite(item) } } label: {
                                Label("收藏", systemImage: item.isFavorite ? "star.slash" : "star")
                            }
                            .tint(.orange)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("TrendRadar")
            .searchable(text: $searchText, prompt: "搜索热点")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingFavorites.toggle() } label: {
                        Image(systemName: showingFavorites ? "star.fill" : "star")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                            .disabled(store.isRefreshing)
                        Button { showingSettings = true } label: { Image(systemName: "gear") }
                    }
                }
            }
            .refreshable { await store.refresh() }
            .task { await store.requestNotifications() }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .alert("提示", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("确定", role: .cancel) { store.errorMessage = nil }
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
    }
}

private struct NewsRow: View {
    let item: NewsItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.headline)
                .foregroundStyle(item.isRead ? .secondary : .primary)
            HStack {
                Text(item.source)
                if item.isFavorite { Image(systemName: "star.fill").foregroundStyle(.orange) }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
    }
}

private struct NewsDetailView: View {
    let item: NewsItem
    @EnvironmentObject private var store: NewsStore
    @State private var isSummarizing = false
    @State private var generatedSummary: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.title).font(.title2.bold())
                Text(item.source).font(.subheadline).foregroundStyle(.secondary)
                if let summary = generatedSummary ?? item.summary, !summary.isEmpty { Text(summary).font(.body) }
                Button {
                    isSummarizing = true
                    Task {
                        await store.summarize(item)
                        generatedSummary = store.items.first(where: { $0.id == item.id })?.summary
                        isSummarizing = false
                    }
                } label: {
                    Label(isSummarizing ? "分析中..." : "AI 摘要", systemImage: "sparkles")
                }
                .buttonStyle(.bordered)
                .disabled(isSummarizing)
                if let url = item.url {
                    Link("阅读原文", destination: url)
                        .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}
