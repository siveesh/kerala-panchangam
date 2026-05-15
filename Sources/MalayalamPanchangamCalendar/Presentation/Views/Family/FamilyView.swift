import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - FamilyView

/// Master-detail view for the Family section.
/// Left pane: profile list. Right pane: PersonFormView for the selected profile.
/// Bottom strip: Śrāddham dates for all deceased family members in the loaded year.
struct FamilyView: View {

    @Bindable var viewModel: FamilyViewModel

    @State private var showDeleteAlert = false
    @State private var showScheduleConfirmation = false
    @State private var showRemindersConfirmation = false
    @State private var showingImportConfirm = false

    var body: some View {
        HSplitView {
            sidebarPane
                .frame(minWidth: 200, idealWidth: 240, maxWidth: 300, maxHeight: .infinity)

            detailPane
                .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            if !viewModel.shraddhamDates.isEmpty {
                shraddhamStrip
            }
        }
        .alert("Delete Profile?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteSelected() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let name = viewModel.selectedProfile?.displayName {
                Text("\"\(name)\" and all associated data will be permanently removed.")
            }
        }
        .alert("Added to Apple Calendar", isPresented: $showScheduleConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Family birthday and Śrāddham events have been added to the 'Malayalam Panchangam' calendar.")
        }
        .alert("Saved to Reminders", isPresented: $showRemindersConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Family birthday and Śrāddham reminders have been saved to the Reminders page and OS notifications scheduled.")
        }
        .task { await viewModel.loadProfiles() }
        // Export: present save panel when exportedFileURL is set
        .onChange(of: viewModel.exportedFileURL) { _, url in
            guard let url else { return }
            NSSavePanel.saveCopy(of: url, suggestedName: url.lastPathComponent)
            viewModel.exportedFileURL = nil
        }
        // Import: file picker
        .fileImporter(
            isPresented: $viewModel.showingImportFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                showingImportConfirm = true
                Task { @MainActor in
                    viewModel.pendingImportURL = url
                }
            case .failure(let error):
                viewModel.importExportError = error.localizedDescription
                viewModel.showingImportError = true
            }
        }
        // Import confirmation alert
        .alert("Replace All Profiles?", isPresented: $showingImportConfirm) {
            Button("Replace", role: .destructive) {
                if let url = viewModel.pendingImportURL {
                    Task { await viewModel.importBackup(from: url) }
                }
            }
            Button("Cancel", role: .cancel) { viewModel.pendingImportURL = nil }
        } message: {
            Text("This will replace ALL existing profiles with the ones in the backup file. This cannot be undone.")
        }
        // Export error
        .alert("Export Failed", isPresented: $viewModel.showingExportError) {
            Button("OK", role: .cancel) { viewModel.showingExportError = false }
        } message: {
            Text(viewModel.importExportError ?? "Unknown error")
        }
        // Import error
        .alert("Import Failed", isPresented: $viewModel.showingImportError) {
            Button("OK", role: .cancel) { viewModel.showingImportError = false }
        } message: {
            Text(viewModel.importExportError ?? "Unknown error")
        }
        // Load the selected profile into draft when the sidebar selection changes
        .onChange(of: viewModel.selectedProfileID) { _, newID in
            guard let id = newID,
                  let profile = viewModel.profiles.first(where: { $0.id == id }) else { return }
            viewModel.edit(profile: profile)
        }
    }

    // MARK: - Sidebar Pane

    private var sidebarPane: some View {
        VStack(spacing: 0) {
            // Using maxHeight: .infinity on the VStack so the sidebar fills the split pane height
            // Toolbar
            HStack {
                Text("Family")
                    .font(.headline)
                    .padding(.leading, 8)
                Spacer()

                Button {
                    Task { await viewModel.exportBackup() }
                } label: {
                    Image(systemName: "arrow.up.doc")
                }
                .help("Export profiles backup")

                Button {
                    viewModel.showingImportFilePicker = true
                } label: {
                    Image(systemName: "arrow.down.doc")
                }
                .help("Restore profiles from backup")

                Button {
                    viewModel.startNewProfile()
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .help("Add new person")

                Button {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete selected profile")
                .disabled(viewModel.selectedProfileID == nil)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.profiles.isEmpty {
                ContentUnavailableView(
                    "No Profiles",
                    systemImage: "person.2",
                    description: Text("Tap + to add a family member.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.activeProfiles, selection: $viewModel.selectedProfileID) { profile in
                    profileRow(profile)
                        .tag(profile.id)
                        .contextMenu {
                            Button {
                                viewModel.edit(profile: profile)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button {
                                Task { await viewModel.toggleArchive(profile: profile) }
                            } label: {
                                Label(profile.isArchived ? "Unarchive" : "Archive",
                                      systemImage: profile.isArchived ? "tray.and.arrow.up" : "archivebox")
                            }
                            Divider()
                            Button(role: .destructive) {
                                viewModel.selectedProfileID = profile.id
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func profileRow(_ profile: PersonProfile) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: profile.isDeceased ? "leaf.fill" : "person.fill")
                    .foregroundStyle(profile.isDeceased ? Color.secondary : Color.accentColor)
                    .font(.caption)
                Text(profile.displayName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                if !profile.relationshipTag.isEmpty {
                    Text(profile.relationshipTag)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let nak = profile.birthDetails?.birthNakshatra {
                    Text("★ \(nak.englishName)")
                        .font(.caption2)
                        .foregroundStyle(.green.opacity(0.8))
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        if viewModel.selectedProfileID == nil && !viewModel.isDraftNew {
            // Nothing selected, no active draft
            VStack(spacing: 12) {
                ContentUnavailableView(
                    "Select or Create a Profile",
                    systemImage: "person.crop.rectangle.stack",
                    description: Text("Choose a person from the list or tap + to add a new family member.")
                )
                scheduleAllButton
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                // Header toolbar
                HStack {
                    Text(viewModel.isDraftNew ? "New Profile" : (viewModel.draft.displayName.isEmpty ? "Edit Profile" : viewModel.draft.displayName))
                        .font(.headline)
                        .padding(.leading)

                    Spacer()

                    if viewModel.isLoading {
                        ProgressView().scaleEffect(0.7)
                    }

                    if let err = viewModel.errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }

                    Button("Save") {
                        Task { await viewModel.saveDraft() }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("s", modifiers: .command)
                    .padding(.trailing)
                }
                .padding(.vertical, 8)
                .background(.bar)

                Divider()

                PersonFormView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                HStack {
                    scheduleAllButton
                    Spacer()
                    // Deceased toggle
                    Toggle("Deceased", isOn: Binding(
                        get: { viewModel.draft.isDeceased },
                        set: { on in
                            if on {
                                viewModel.draft.deathDetails = DeathDetails()
                            } else {
                                viewModel.draft.deathDetails = nil
                                viewModel.draft.deathGrahanila = .empty
                            }
                        }
                    ))
                    .toggleStyle(.checkbox)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var scheduleAllButton: some View {
        HStack(spacing: 8) {
            Button {
                Task {
                    await viewModel.addToCalendar()
                    showScheduleConfirmation = true
                }
            } label: {
                Label("Add to Apple Calendar", systemImage: "calendar.badge.plus")
            }
            .disabled(viewModel.days.isEmpty || viewModel.activeProfiles.isEmpty)
            .help(viewModel.days.isEmpty
                  ? "Load a Panchangam year first"
                  : "Add family birthday and Śrāddham events to Apple Calendar")

            Button {
                Task {
                    await viewModel.addToReminders()
                    showRemindersConfirmation = true
                }
            } label: {
                Label("Save to Reminders", systemImage: "bell.badge")
            }
            .disabled(viewModel.days.isEmpty || viewModel.activeProfiles.isEmpty)
            .help(viewModel.days.isEmpty
                  ? "Load a Panchangam year first"
                  : "Save family reminders to the Reminders page and schedule notifications")
        }
    }

    // MARK: - Śrāddham Strip

    private var shraddhamStrip: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    Text("Śrāddham Dates:")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 12)

                    ForEach(viewModel.shraddhamDates) { date in
                        HStack(spacing: 4) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(date.personName)
                                    .font(.caption2.weight(.medium))
                                Text("\(date.date, style: .date) · \(date.paksha.shortName) \(date.tithi.englishName)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
        }
        .background(.bar)
    }
}

// MARK: - ShraddhamDate date helper

private extension ShraddhamDate {
    var date: Date { gregorianDate }
}

// MARK: - NSSavePanel helper

private extension NSSavePanel {
    static func saveCopy(of sourceURL: URL, suggestedName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [.json]
        panel.message = "Choose where to save your profiles backup"
        panel.begin { response in
            guard response == .OK, let dest = panel.url else { return }
            try? FileManager.default.copyItem(at: sourceURL, to: dest)
        }
    }
}
