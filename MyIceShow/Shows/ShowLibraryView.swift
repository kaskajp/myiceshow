import SwiftUI

struct ShowLibraryView: View {
    let shows: [SavedShow]
    let loadError: String?
    let onRetry: () -> Void
    let onCreate: () -> Void
    let onOpen: (SavedShow) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let loadError {
                    ContentUnavailableView {
                        Label("Your shows are unavailable", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(loadError)
                    } actions: {
                        Button("Try again", action: onRetry)
                            .buttonStyle(.borderedProminent)
                    }
                } else if shows.isEmpty {
                    ContentUnavailableView(
                        "Your first show awaits",
                        systemImage: "sparkles",
                        description: Text("Save a show in the studio, then find it here to play or edit again.")
                    )
                } else {
                    List(shows) { show in
                        Button {
                            onOpen(show)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "snowflake")
                                    .font(.title2)
                                    .foregroundStyle(Color(uiColor: show.content.costume.uiColor))
                                    .frame(width: 42, height: 48)
                                    .background(StudioTheme.lavender, in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(show.content.title)
                                        .font(.headline)
                                        .foregroundStyle(StudioTheme.ink)
                                    Text("\(show.content.clips.count) moves · \(SkatingMotion.duration(of: show.content.clips).formatted(.number.precision(.fractionLength(0...1))))s")
                                        .font(.subheadline)
                                        .foregroundStyle(StudioTheme.ink.opacity(0.65))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                        .accessibilityLabel("Open \(show.content.title), \(show.content.clips.count) moves")
                    }
                }
            }
            .navigationTitle("My shows")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New show", systemImage: "plus", action: onCreate)
                }
            }
            .tint(StudioTheme.accent)
        }
    }
}
