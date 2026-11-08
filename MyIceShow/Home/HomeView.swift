import SwiftUI

struct HomeView: View {
    let recentShows: [SavedShow]
    let hasLibraryError: Bool
    let onCreate: () -> Void
    let onContinue: () -> Void
    let onShowLibrary: () -> Void
    let onOpenShow: (SavedShow) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Label("MY ICE SHOW", systemImage: "snowflake")
                    .font(.caption.weight(.heavy))
                    .tracking(2)
                    .padding(.top, 8)
                welcome
                recentShowsSection
                Text("Made for your imagination. Saved on your device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
        }
        .background(StudioTheme.background)
        .foregroundStyle(StudioTheme.ink)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(StudioTheme.accent)
                .frame(width: 76, height: 76)
                .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 24))
                .accessibilityHidden(true)
            Text("A little ice.\nA lot of imagination.")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            Text("Choose your moves, add your own flair, and bring a show to life.")
                .font(.subheadline)
                .foregroundStyle(StudioTheme.ink.opacity(0.7))
            Button(action: onCreate) {
                Label("Create a new show", systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(.white)
                    .background(StudioTheme.accent, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            Button(action: onContinue) {
                Label("Continue in Studio", systemImage: "pencil.and.outline")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [StudioTheme.lavender, StudioTheme.lavender.opacity(0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28)
        )
    }

    private var recentShowsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your shows")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Spacer()
                Button("See all", action: onShowLibrary)
                    .font(.subheadline.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
            }
            if hasLibraryError {
                Text("Your saved shows couldn't be read. Open Shows to see details and try again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20))
            } else if recentShows.isEmpty {
                Text("Your first show is waiting to happen. Create one in the studio, then save it here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20))
            } else {
                ForEach(recentShows) { show in
                    Button {
                        onOpenShow(show)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "snowflake")
                                .font(.title2)
                                .foregroundStyle(Color(uiColor: show.content.costume.uiColor))
                                .frame(width: 44, height: 44)
                                .background(StudioTheme.lavender, in: RoundedRectangle(cornerRadius: 14))
                            Text(show.content.title)
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(StudioTheme.accent)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(show.content.title)")
                }
            }
        }
    }
}
