import SwiftUI

struct StudioView: View {
    let showLibrary: ShowLibrary
    let request: StudioRequest?
    let isActive: Bool
    let onRequestHandled: () -> Void
    let onShowLibrary: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var player = ShowPlayer()
    @State private var clips: [RoutineClip]
    @State private var selectedID: UUID?
    @State private var costume: CostumeColor = .lilac
    @State private var showTitle = "My first show"
    @State private var currentShowID: UUID?
    @State private var savedContent: ShowContent?
    @State private var draftBaseline: ShowContent
    @State private var pendingDestination: StudioDestination?
    @State private var isDiscardPromptPresented = false
    @State private var saveError: String?
    @FocusState private var isEditingName: Bool

    init(
        showLibrary: ShowLibrary,
        request: StudioRequest?,
        isActive: Bool,
        onRequestHandled: @escaping () -> Void,
        onShowLibrary: @escaping () -> Void
    ) {
        self.showLibrary = showLibrary
        self.request = request
        self.isActive = isActive
        self.onRequestHandled = onRequestHandled
        self.onShowLibrary = onShowLibrary
        let initialClips = SkatingMove.allCases.map { RoutineClip(move: $0) }
        _clips = State(initialValue: initialClips)
        _draftBaseline = State(initialValue: ShowContent(title: "My first show", clips: initialClips, costume: .lilac))
    }

    private var duration: Double { SkatingMotion.duration(of: clips) }
    private var sample: MotionSample { SkatingMotion.sample(clips: clips, at: player.elapsed) }
    private var selectedIndex: Int? { clips.firstIndex { $0.id == selectedID } }
    private var currentContent: ShowContent { ShowContent(title: showTitle, clips: clips, costume: costume) }
    private var hasUnsavedChanges: Bool {
        currentContent != (savedContent ?? draftBaseline)
    }
    private var canSave: Bool {
        let title = showTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return !clips.isEmpty && !title.isEmpty && title.count <= ShowContent.maximumTitleLength
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                stage
                playback
                showControls
                routine
                library
                Text("Animation study · Procedural poses, not coach-validated skating. Saved shows stay on this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
        }
        .background(StudioTheme.background)
        .foregroundStyle(StudioTheme.ink)
        .tint(StudioTheme.accent)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: request?.id, initial: true) { _, _ in
            guard let request else { return }
            requestNavigation(request.destination)
            onRequestHandled()
        }
        .onChange(of: isActive) { _, active in
            guard !active else { return }
            player.pause()
            isEditingName = false
        }
        .confirmationDialog("Save your changes?", isPresented: $isDiscardPromptPresented, titleVisibility: .visible) {
            Button("Save and continue") {
                guard saveCurrentShow() else { return }
                finishNavigation()
            }
            .disabled(!canSave || !showLibrary.isReady)
            Button("Discard changes", role: .destructive, action: finishNavigation)
            Button("Cancel", role: .cancel) { pendingDestination = nil }
        } message: {
            Text("Your current edits have not been saved. Keep them before leaving this show, or discard only the unsaved changes.")
        }
        .alert("Couldn't save your show", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { player.pause() }
        }
        .onDisappear { player.pause() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("MY ICE SHOW", systemImage: "snowflake")
                    .font(.caption.weight(.heavy))
                    .tracking(2)
                Spacer()
                Text("ANIMATION LAB")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(StudioTheme.lavender, in: Capsule())
            }
            Text("Your ice, your show.")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("A few moves. A little music. Something all yours.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var stage: some View {
        VStack(spacing: 0) {
            RinkView(sample: sample, costume: costume)
                .frame(height: 300)
                .overlay(alignment: .topLeading) {
                    Label(player.isPlaying ? sample.move.title : "Your practice rink", systemImage: "sparkle")
                        .font(.caption.weight(.semibold))
                        .padding(10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(14)
                }
                .accessibilityLabel("3D practice rink. Current move: \(sample.move.title)")
            HStack {
                Text("COSTUME COLOR")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                Spacer()
                ForEach(CostumeColor.allCases) { color in
                    Button {
                        costume = color
                    } label: {
                        Circle()
                            .fill(Color(uiColor: color.uiColor))
                            .frame(width: 24, height: 24)
                            .padding(5)
                            .overlay(Circle().strokeBorder(costume == color ? StudioTheme.ink : .clear, lineWidth: 1.5))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(color.rawValue) costume")
                    .accessibilityAddTraits(costume == color ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var showControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Your show", systemImage: "sparkles")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Button("My shows", systemImage: "rectangle.stack") {
                    player.pause()
                    isEditingName = false
                    onShowLibrary()
                }
                .font(.subheadline.weight(.semibold))
            }
            HStack(spacing: 12) {
                TextField("Give your show a name", text: $showTitle)
                    .font(.headline)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isEditingName)
                    .onSubmit { isEditingName = false }
                    .accessibilityLabel("Show name")
                Button(currentShowID == nil ? "Save show" : "Save changes") {
                    saveCurrentShow()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canSave || !showLibrary.isReady || (currentShowID != nil && !hasUnsavedChanges))
            }
            HStack {
                Label(
                    currentShowID != nil && !hasUnsavedChanges ? "Saved on this device" : "Changes not saved",
                    systemImage: currentShowID != nil && !hasUnsavedChanges ? "checkmark.circle" : "pencil.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                Button("New show", systemImage: "plus") { requestNavigation(.newShow) }
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: 44)
            }
            if showTitle.trimmingCharacters(in: .whitespacesAndNewlines).count > ShowContent.maximumTitleLength {
                Text("Use a name of 80 characters or fewer.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if showLibrary.loadError != nil {
                Text("Saved shows are unavailable. Open My shows for details. Your current routine is still here.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private var playback: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    if player.isPlaying {
                        player.pause()
                    } else {
                        player.play(duration: duration)
                    }
                } label: {
                    Label(player.isPlaying ? "Pause show" : "Play show", systemImage: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(.white)
                        .background(StudioTheme.accent, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(clips.isEmpty)

                Button("Restart show", systemImage: "backward.end.fill") { player.reset() }
                    .labelStyle(.iconOnly)
                    .frame(width: 48, height: 48)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))

                Button(player.soundEnabled ? "Mute timing pulse" : "Unmute timing pulse", systemImage: player.soundEnabled ? "speaker.wave.2" : "speaker.slash") {
                    player.soundEnabled.toggle()
                }
                .labelStyle(.iconOnly)
                .frame(width: 48, height: 48)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
            }

            Slider(
                value: Binding(get: { player.elapsed }, set: { player.seek(to: $0, duration: duration) }),
                in: 0...max(duration, 0.01)
            )
            .disabled(clips.isEmpty)
            .accessibilityLabel("Show position")
            .accessibilityValue("\(player.elapsed.formatted(.number.precision(.fractionLength(1)))) of \(duration.formatted(.number.precision(.fractionLength(1)))) seconds")

            HStack {
                Label("Timing pulse · 120 BPM", systemImage: "waveform")
                Spacer()
                Text("\(clock(player.elapsed)) / \(clock(duration))")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let error = player.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
    }

    private var routine: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your choreography")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Spacer()
                Text("\(clips.count) moves · \(duration.formatted(.number.precision(.fractionLength(0...1))))s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Tap a card to edit. Add something new below.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if clips.isEmpty {
                ContentUnavailableView("A fresh sheet of ice", systemImage: "snowflake", description: Text("Choose a move below to begin your show."))
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                            moveCard(clip, number: index + 1)
                                .id(clip.id)
                        }
                    }
                    .padding(2)
                }
                .onChange(of: selectedID) { _, clipID in
                    guard let clipID else { return }
                    withAnimation { proxy.scrollTo(clipID, anchor: .center) }
                }
            }

            if let index = selectedIndex {
                editor(index: index)
            }
        }
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("A little inspiration")
                .font(.system(.title3, design: .rounded, weight: .bold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], spacing: 10) {
                ForEach(SkatingMove.allCases) { move in
                    Button {
                        player.reset()
                        let clip = RoutineClip(move: move)
                        clips.append(clip)
                        selectedID = clip.id
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: move.symbol)
                                .frame(width: 24)
                            Text(move.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer(minLength: 0)
                            Image(systemName: "plus")
                                .font(.caption.weight(.bold))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add \(move.title)")
                    .disabled(duration + move.defaultDuration > SkatingMotion.maximumDuration)
                }
            }
            Text("Five study moves · Up to 60 seconds · Not the final move collection")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func moveCard(_ clip: RoutineClip, number: Int) -> some View {
        let isActive = player.isPlaying && sample.clipID == clip.id
        let isSelected = selectedID == clip.id
        return Button {
            player.pause()
            selectedID = clip.id
            let start = clips.prefix { $0.id != clip.id }.reduce(0) { $0 + $1.duration }
            player.seek(to: start, duration: duration)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: clip.move.symbol)
                        .font(.title2)
                    Spacer()
                    Text(String(format: "%02d", number))
                        .font(.caption2.weight(.bold))
                        .opacity(0.55)
                }
                Text(clip.move.title)
                    .font(.subheadline.weight(.bold))
                Text("\(clip.duration.formatted(.number.precision(.fractionLength(1)))) seconds")
                    .font(.caption)
                    .opacity(0.65)
            }
            .frame(width: 115, alignment: .leading)
            .padding(14)
            .background(isActive ? StudioTheme.accent : isSelected ? StudioTheme.lavender : .white, in: RoundedRectangle(cornerRadius: 18))
            .foregroundStyle(isActive ? .white : StudioTheme.ink)
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(isSelected ? StudioTheme.accent : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Move \(number), \(clip.move.title), \(clip.duration.formatted()) seconds. Edit move")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func editor(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Edit \(clips[index].move.title)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Close move editor", systemImage: "xmark") { selectedID = nil }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
            }
            HStack {
                Button("Move earlier", systemImage: "arrow.left") { reorder(index: index, offset: -1) }
                    .disabled(index == 0)
                Button("Move later", systemImage: "arrow.right") { reorder(index: index, offset: 1) }
                    .disabled(index == clips.count - 1)
                Spacer()
                Button("Remove move", systemImage: "trash", role: .destructive) {
                    player.reset()
                    clips.remove(at: index)
                    selectedID = nil
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)

            Stepper(
                "Duration: \(clips[index].duration.formatted(.number.precision(.fractionLength(1))))s",
                value: Binding(
                    get: { clips[index].duration },
                    set: { newDuration in
                        player.reset()
                        clips[index].duration = newDuration
                    }
                ),
                in: clips[index].move.minimumDuration...min(SkatingMotion.maximumClipDuration, SkatingMotion.maximumDuration - duration + clips[index].duration),
                step: 0.5
            )
            .font(.subheadline)
            if clips[index].move == .waltzJump {
                Text("The 0.6s jump flight stays fixed; duration adjusts the approach and exit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private func reorder(index: Int, offset: Int) {
        player.reset()
        clips.swapAt(index, index + offset)
    }

    @discardableResult
    private func saveCurrentShow() -> Bool {
        isEditingName = false
        do {
            let show = try showLibrary.save(content: currentContent, id: currentShowID)
            showTitle = show.content.title
            currentShowID = show.id
            savedContent = show.content
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }

    private func requestNavigation(_ destination: StudioDestination) {
        if case .savedShow(let show) = destination, show.id == currentShowID { return }
        player.pause()
        isEditingName = false
        pendingDestination = destination
        guard hasUnsavedChanges else {
            finishNavigation()
            return
        }
        isDiscardPromptPresented = true
    }

    private func finishNavigation() {
        guard let destination = pendingDestination else { return }
        player.reset()
        selectedID = nil
        switch destination {
        case .newShow:
            clips = []
            costume = .lilac
            showTitle = "My new show"
            currentShowID = nil
            savedContent = nil
            draftBaseline = currentContent
        case .savedShow(let show):
            clips = show.content.clips
            costume = show.content.costume
            showTitle = show.content.title
            currentShowID = show.id
            savedContent = show.content
        }
        pendingDestination = nil
    }

    private func clock(_ time: Double) -> String {
        let seconds = Int(time)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
