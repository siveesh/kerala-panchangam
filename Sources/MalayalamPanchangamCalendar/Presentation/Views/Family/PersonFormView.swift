import SwiftUI

// MARK: - PersonFormView

/// Sectioned form for creating and editing a PersonProfile.
/// Binds directly to `viewModel.draft`.
struct PersonFormView: View {

    @Bindable var viewModel: FamilyViewModel

    @State private var showBirthLocationSheet = false
    @State private var showDeathLocationSheet = false
    @State private var showBirthGrahanilaEditor = false
    @State private var showHoroscopeExport = false
    @State private var showPIIExportWarning = false
    @State private var birthLocationProxy = GeoLocation.thrissur
    @State private var deathLocationProxy = GeoLocation.thrissur
    @State private var useCustomRelationship = false

    // Standard relationship options for the dropdown
    private static let relationshipOptions: [String] = [
        "Self", "Father", "Mother", "Spouse",
        "Son", "Daughter", "Brother", "Sister",
        "Grandfather", "Grandmother",
        "Uncle", "Aunt",
        "Father-in-law", "Mother-in-law",
        "Son-in-law", "Daughter-in-law",
        "Brother-in-law", "Sister-in-law"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                identitySection
                Divider().padding(.vertical, 8)
                birthSection
                Divider().padding(.vertical, 8)
                // Deceased toggle is a named section so it is always clearly visible
                deceasedToggleSection
                if viewModel.draft.isDeceased {
                    Divider().padding(.vertical, 8)
                    deathSection
                }
                Divider().padding(.vertical, 8)
                reminderSection
                Divider().padding(.vertical, 8)
                exportSection
            }
            .padding()
        }
        // Conflict banner (appears between sections when conflicts are found)
        .safeAreaInset(edge: .top) {
            if !viewModel.pendingConflicts.isEmpty {
                conflictBanner
            }
        }
        .sheet(isPresented: $showBirthLocationSheet) {
            LocationSelectionView(selectedLocation: $birthLocationProxy)
                .onDisappear {
                    viewModel.draft.birthDetails?.birthLocation = birthLocationProxy
                }
        }
        .sheet(isPresented: $showDeathLocationSheet) {
            LocationSelectionView(selectedLocation: $deathLocationProxy)
                .onDisappear {
                    viewModel.draft.deathDetails?.deathLocation = deathLocationProxy
                }
        }
        .sheet(isPresented: $showBirthGrahanilaEditor) {
            NavigationStack {
                ManualGrahanilaEditorView(
                    grahanila: $viewModel.draft.birthGrahanila,
                    isReadOnly: false,
                    centerLabel: viewModel.draft.displayName.isEmpty ? "Birth" : viewModel.draft.displayName
                )
                .padding()
                .navigationTitle("Birth Grahanila")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showBirthGrahanilaEditor = false }
                    }
                }
            }
            .frame(minWidth: 480, minHeight: 540)
        }
        .sheet(isPresented: $showHoroscopeExport) {
            HoroscopeExportView(
                profile: viewModel.draft,
                ayanamsa: viewModel.ayanamsaSelection
            )
        }
        .onAppear {
            birthLocationProxy = viewModel.draft.birthDetails?.birthLocation ?? .thrissur
            deathLocationProxy = viewModel.draft.deathDetails?.deathLocation ?? .thrissur
            let tag = viewModel.draft.relationshipTag
            useCustomRelationship = !tag.isEmpty && !Self.relationshipOptions.contains(tag)
        }
    }

    // MARK: - Identity Section

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Identity", systemImage: "person.crop.circle")

            LabeledTextField("Full Name", text: $viewModel.draft.fullName,
                             prompt: "e.g. Krishnan Nair",
                             maxLength: 255,
                             validate: { s in s.trimmingCharacters(in: .whitespaces).isEmpty ? "Name is required." : nil })
            LabeledTextField("Nickname / Short Name", text: $viewModel.draft.nickname,
                             prompt: "Optional",
                             maxLength: 80)

            // Relationship — dropdown + optional custom text field
            LabeledContent("Relationship") {
                HStack(spacing: 8) {
                    Picker("", selection: Binding<String>(
                        get: {
                            let tag = viewModel.draft.relationshipTag
                            return Self.relationshipOptions.contains(tag) ? tag : "Custom…"
                        },
                        set: { picked in
                            if picked == "Custom…" {
                                useCustomRelationship = true
                                // Clear preset so custom field gets focus
                                if Self.relationshipOptions.contains(viewModel.draft.relationshipTag) {
                                    viewModel.draft.relationshipTag = ""
                                }
                            } else {
                                viewModel.draft.relationshipTag = picked
                                useCustomRelationship = false
                            }
                        }
                    )) {
                        Text("Select…").tag("")
                        Divider()
                        ForEach(Self.relationshipOptions, id: \.self) { opt in
                            Text(opt).tag(opt)
                        }
                        Divider()
                        Text("Custom…").tag("Custom…")
                    }
                    .frame(maxWidth: 220)
                }
            }

            if useCustomRelationship {
                TextField("Enter relationship", text: $viewModel.draft.relationshipTag)
                    .textFieldStyle(.roundedBorder)
                    .padding(.leading, 10)
            }

            // Additional personal details
            LabeledTextField("Father's Name", text: $viewModel.draft.fatherName,
                             prompt: "Optional",
                             maxLength: 255)
            LabeledTextField("Mother's Name", text: $viewModel.draft.motherName,
                             prompt: "Optional",
                             maxLength: 255)
            LabeledTextField("Mobile Number", text: $viewModel.draft.mobileNumber,
                             prompt: "Optional",
                             maxLength: 20,
                             validate: mobileValidator)
            LabeledTextField("Address", text: $viewModel.draft.address,
                             prompt: "Optional",
                             axis: .vertical,
                             maxLength: 500)

            LabeledTextField("Notes", text: $viewModel.draft.notes,
                             prompt: "Optional notes",
                             axis: .vertical,
                             maxLength: 2000)
        }
    }

    // MARK: - Birth Section

    private var birthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Birth Details", systemImage: "birthday.cake")
                Spacer()
                Toggle("Has birth data", isOn: Binding(
                    get:  { viewModel.draft.birthDetails != nil },
                    set:  { on in
                        viewModel.draft.birthDetails = on ? BirthDetails() : nil
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }

            if viewModel.draft.birthDetails != nil {
                // Date of Birth
                DatePicker(
                    "Date of Birth",
                    selection: Binding(
                        get: { viewModel.draft.birthDetails?.dateOfBirth ?? .now },
                        set: { newDate in
                            viewModel.draft.birthDetails?.dateOfBirth = newDate
                            // Re-anchor birthTime to the new date so the hour/minute
                            // the user entered stays valid after a date change.
                            if let existingTime = viewModel.draft.birthDetails?.birthTime {
                                viewModel.draft.birthDetails?.birthTime =
                                    FamilyViewModel.combine(date: newDate, time: existingTime, in: .current)
                            }
                        }
                    ),
                    displayedComponents: .date
                )

                // Optional birth time
                // NOTE: DatePicker(.hourAndMinute) stores today as the base date.
                // We always merge only the hour/minute onto the actual birth date.
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Birth time known", isOn: Binding(
                        get: { viewModel.draft.birthDetails?.birthTime != nil },
                        set: { on in
                            if on {
                                // Initialise to the actual birth date at the current time of day
                                let birthDate = viewModel.draft.birthDetails?.dateOfBirth ?? .now
                                let now = Date.now
                                viewModel.draft.birthDetails?.birthTime =
                                    FamilyViewModel.combine(date: birthDate, time: now, in: .current)
                                // Store the displayed h/m so the PDF can show them
                                // timezone-independently
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: now)
                                viewModel.draft.birthDetails?.birthTimeDisplayHour   = comps.hour
                                viewModel.draft.birthDetails?.birthTimeDisplayMinute = comps.minute
                            } else {
                                viewModel.draft.birthDetails?.birthTime = nil
                                viewModel.draft.birthDetails?.birthTimeDisplayHour   = nil
                                viewModel.draft.birthDetails?.birthTimeDisplayMinute = nil
                            }
                        }
                    ))
                    if viewModel.draft.birthDetails?.birthTime != nil {
                        DatePicker(
                            "Birth Time",
                            selection: Binding(
                                get: { viewModel.draft.birthDetails?.birthTime ?? .now },
                                set: { picked in
                                    // Extract only hour/minute from picker; keep birth date.
                                    // Also store the raw displayed h/m so PDF display is
                                    // timezone-independent (avoids Mac-tz vs birth-tz confusion).
                                    let birthDate = viewModel.draft.birthDetails?.dateOfBirth ?? .now
                                    viewModel.draft.birthDetails?.birthTime =
                                        FamilyViewModel.combine(date: birthDate, time: picked, in: .current)
                                    let comps = Calendar.current.dateComponents([.hour, .minute], from: picked)
                                    viewModel.draft.birthDetails?.birthTimeDisplayHour   = comps.hour
                                    viewModel.draft.birthDetails?.birthTimeDisplayMinute = comps.minute
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                }

                // Birth location
                HStack {
                    if let loc = viewModel.draft.birthDetails?.birthLocation {
                        Text(loc.name)
                            .font(.callout)
                    } else {
                        Text("Birth Location: not set")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Choose…") {
                        birthLocationProxy = viewModel.draft.birthDetails?.birthLocation ?? .thrissur
                        showBirthLocationSheet = true
                    }
                }

                // Manual Nakshatra selection (works even without birth time / location)
                LabeledContent("Nakshatra") {
                    Picker("", selection: Binding<Nakshatra?>(
                        get: { viewModel.draft.birthDetails?.birthNakshatra },
                        set: { nak in
                            viewModel.draft.birthDetails?.birthNakshatra = nak
                            viewModel.draft.birthDetails?.nakshatraEntry = nak == nil ? .unset : .manual
                        }
                    )) {
                        Text("—").tag(Optional<Nakshatra>.none)
                        ForEach(Nakshatra.allCases) { nak in
                            Text("\(nak.englishName) · \(nak.malayalamName)")
                                .tag(Optional(nak))
                        }
                    }
                    .frame(maxWidth: 240)
                }

                // Calculate button
                Button {
                    Task { await viewModel.recalculateDraft() }
                } label: {
                    Label("Calculate from Date & Location", systemImage: "sparkles")
                }
                .disabled(viewModel.draft.birthDetails?.birthLocation == nil)
                .help("Auto-fills Nakshatra, Tithi and Malayalam date from the selected date and location")

                // Calculated values (read-only grid)
                if let birth = viewModel.draft.birthDetails,
                   birth.birthNakshatra != nil || birth.birthTithi != nil {
                    birthCalculatedValuesGrid(birth)
                }

                // Birth Grahanila disclosure
                DisclosureGroup("Birth Grahanila (\(viewModel.draft.birthGrahanila.mode.title))") {
                    VStack(alignment: .leading, spacing: 8) {
                        ManualGrahanilaEditorView(
                            grahanila: $viewModel.draft.birthGrahanila,
                            isReadOnly: true
                        )
                        .frame(height: 280)

                        HStack {
                            Button {
                                Task { await viewModel.recalculateGrahanila() }
                            } label: {
                                Label("Recalculate", systemImage: "arrow.clockwise")
                            }
                            .disabled(viewModel.draft.birthDetails?.birthLocation == nil)

                            Button("Edit Manually") {
                                showBirthGrahanilaEditor = true
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func birthCalculatedValuesGrid(_ birth: BirthDetails) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 4) {
            if let nak = birth.birthNakshatra {
                GridRow {
                    Text("Nakshatra").foregroundStyle(.secondary).font(.caption)
                    Text("\(nak.englishName) — \(nak.malayalamName)")
                        .font(.caption)
                }
            }
            if let tithi = birth.birthTithi, let paksha = birth.birthPaksha {
                GridRow {
                    Text("Tithi").foregroundStyle(.secondary).font(.caption)
                    Text("\(paksha.shortName) \(tithi.englishName)").font(.caption)
                }
            }
            if let month = birth.birthMalayalamMonth, let day = birth.birthMalayalamDay, let year = birth.birthKollavarshamYear {
                GridRow {
                    Text("Malayalam Date").foregroundStyle(.secondary).font(.caption)
                    Text("\(month.englishName) \(day), \(year) K.E.").font(.caption)
                }
            }
            if let lagna = birth.lagna {
                GridRow {
                    Text("Lagna").foregroundStyle(.secondary).font(.caption)
                    Text(lagna.englishName).font(.caption)
                }
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Deceased Toggle Section

    /// Always-visible section that lets the user mark a person as deceased.
    /// This makes the Deceased toggle discoverable for new profiles.
    private var deceasedToggleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Deceased", systemImage: "leaf")

            HStack(spacing: 12) {
                Toggle(
                    viewModel.draft.isDeceased ? "Person is marked as deceased" : "Mark person as deceased",
                    isOn: Binding(
                        get: { viewModel.draft.isDeceased },
                        set: { on in
                            if on {
                                viewModel.draft.deathDetails = DeathDetails()
                            } else {
                                viewModel.draft.deathDetails = nil
                                viewModel.draft.deathGrahanila = .empty
                            }
                        }
                    )
                )
                .toggleStyle(.switch)

                if viewModel.draft.isDeceased {
                    Text("Death details section is shown below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Death Section

    private var deathSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Death Details", systemImage: "leaf")
                Spacer()
                Button("Remove Death Record", role: .destructive) {
                    viewModel.draft.deathDetails = nil
                    viewModel.draft.deathGrahanila = .empty
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .font(.caption)
            }

            if viewModel.draft.deathDetails != nil {
                DatePicker(
                    "Date of Death",
                    selection: Binding(
                        get: { viewModel.draft.deathDetails?.dateOfDeath ?? .now },
                        set: { newDate in
                            viewModel.draft.deathDetails?.dateOfDeath = newDate
                            // Re-anchor deathTime to the new death date
                            if let existingTime = viewModel.draft.deathDetails?.deathTime {
                                viewModel.draft.deathDetails?.deathTime =
                                    FamilyViewModel.combine(date: newDate, time: existingTime, in: .current)
                            }
                        }
                    ),
                    displayedComponents: .date
                )

                // NOTE: Same DatePicker base-date issue as birth time. See above.
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Death time known", isOn: Binding(
                        get: { viewModel.draft.deathDetails?.deathTime != nil },
                        set: { on in
                            if on {
                                let deathDate = viewModel.draft.deathDetails?.dateOfDeath ?? .now
                                let now = Date.now
                                viewModel.draft.deathDetails?.deathTime =
                                    FamilyViewModel.combine(date: deathDate, time: now, in: .current)
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: now)
                                viewModel.draft.deathDetails?.deathTimeDisplayHour   = comps.hour
                                viewModel.draft.deathDetails?.deathTimeDisplayMinute = comps.minute
                            } else {
                                viewModel.draft.deathDetails?.deathTime = nil
                                viewModel.draft.deathDetails?.deathTimeDisplayHour   = nil
                                viewModel.draft.deathDetails?.deathTimeDisplayMinute = nil
                            }
                        }
                    ))
                    if viewModel.draft.deathDetails?.deathTime != nil {
                        DatePicker(
                            "Death Time",
                            selection: Binding(
                                get: { viewModel.draft.deathDetails?.deathTime ?? .now },
                                set: { picked in
                                    let deathDate = viewModel.draft.deathDetails?.dateOfDeath ?? .now
                                    viewModel.draft.deathDetails?.deathTime =
                                        FamilyViewModel.combine(date: deathDate, time: picked, in: .current)
                                    let comps = Calendar.current.dateComponents([.hour, .minute], from: picked)
                                    viewModel.draft.deathDetails?.deathTimeDisplayHour   = comps.hour
                                    viewModel.draft.deathDetails?.deathTimeDisplayMinute = comps.minute
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                }

                HStack {
                    if let loc = viewModel.draft.deathDetails?.deathLocation {
                        Text(loc.name).font(.callout)
                    } else {
                        Text("Death Location: not set").font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Choose…") {
                        deathLocationProxy = viewModel.draft.deathDetails?.deathLocation ?? .thrissur
                        showDeathLocationSheet = true
                    }
                }

                // Manual Nakshatra selection for death date
                LabeledContent("Nakshatra") {
                    Picker("", selection: Binding<Nakshatra?>(
                        get: { viewModel.draft.deathDetails?.deathNakshatra },
                        set: { nak in
                            viewModel.draft.deathDetails?.deathNakshatra = nak
                            viewModel.draft.deathDetails?.nakshatraEntry = nak == nil ? .unset : .manual
                        }
                    )) {
                        Text("—").tag(Optional<Nakshatra>.none)
                        ForEach(Nakshatra.allCases) { nak in
                            Text("\(nak.englishName) · \(nak.malayalamName)")
                                .tag(Optional(nak))
                        }
                    }
                    .frame(maxWidth: 240)
                }

                Button {
                    Task { await viewModel.recalculateDraft() }
                } label: {
                    Label("Calculate from Date & Location", systemImage: "sparkles")
                }
                .disabled(viewModel.draft.deathDetails?.deathLocation == nil)
                .help("Auto-fills Nakshatra, Tithi and Malayalam date from the selected date and location")

                if let death = viewModel.draft.deathDetails,
                   death.deathNakshatra != nil || death.deathTithi != nil {
                    deathCalculatedValuesGrid(death)
                }
            }
        }
    }

    @ViewBuilder
    private func deathCalculatedValuesGrid(_ death: DeathDetails) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 4) {
            if let nak = death.deathNakshatra {
                GridRow {
                    Text("Nakshatra").foregroundStyle(.secondary).font(.caption)
                    Text("\(nak.englishName) · \(nak.malayalamName)").font(.caption)
                }
            }
            if let tithi = death.deathTithi {
                GridRow {
                    Text("Tithi").foregroundStyle(.secondary).font(.caption)
                    Text(tithi.englishName).font(.caption)
                }
            }
            // Paksha is shown as its own row — important for Śrāddham observance
            if let paksha = death.deathPaksha {
                GridRow {
                    Text("Paksha").foregroundStyle(.secondary).font(.caption)
                    Text("\(paksha.englishName) · \(paksha.malayalamName)").font(.caption)
                }
            }
            if let month = death.deathMalayalamMonth, let day = death.deathMalayalamDay, let year = death.deathKollavarshamYear {
                GridRow {
                    Text("Malayalam Date").foregroundStyle(.secondary).font(.caption)
                    Text("\(month.englishName) \(day), \(year) K.E.").font(.caption)
                }
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Reminder Section

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Reminder Preferences", systemImage: "bell.badge")

            // Birthday reminder
            Toggle("Birthday Reminder", isOn: $viewModel.draft.reminderPreferences.enableBirthdayReminder)
            if viewModel.draft.reminderPreferences.enableBirthdayReminder {
                DatePicker(
                    "Reminder Time",
                    selection: Binding(
                        get: {
                            let comps = viewModel.draft.reminderPreferences.birthdayReminderTime
                            return Calendar.current.date(from: comps) ?? .now
                        },
                        set: {
                            viewModel.draft.reminderPreferences.birthdayReminderTime =
                                Calendar.current.dateComponents([.hour, .minute], from: $0)
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )

                HStack {
                    Text("Advance Notice")
                        .font(.callout)
                    Spacer()
                    Stepper(
                        "\(viewModel.draft.reminderPreferences.birthdayReminderAdvanceMinutes) min",
                        value: $viewModel.draft.reminderPreferences.birthdayReminderAdvanceMinutes,
                        in: 0...120, step: 5
                    )
                }

                HStack {
                    Text("Duplicate Star Policy")
                        .font(.callout)
                    Spacer()
                    Picker("", selection: $viewModel.draft.reminderPreferences.birthdayNakshatraPolicy) {
                        ForEach(DuplicateNakshatraPolicy.allCases) { policy in
                            Text(policy.title).tag(policy)
                        }
                    }
                    .frame(maxWidth: 200)
                }
            }

            Divider().padding(.vertical, 4)

            // Śrāddham reminder
            if viewModel.draft.isDeceased {
                Toggle("Śrāddham Reminder", isOn: $viewModel.draft.reminderPreferences.enableShraddhamReminder)
                if viewModel.draft.reminderPreferences.enableShraddhamReminder {
                    DatePicker(
                        "Reminder Time",
                        selection: Binding(
                            get: {
                                let comps = viewModel.draft.reminderPreferences.shraddhamReminderTime
                                return Calendar.current.date(from: comps) ?? .now
                            },
                            set: {
                                viewModel.draft.reminderPreferences.shraddhamReminderTime =
                                    Calendar.current.dateComponents([.hour, .minute], from: $0)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )

                    HStack {
                        Text("Advance Notice")
                            .font(.callout)
                        Spacer()
                        Stepper(
                            "\(viewModel.draft.reminderPreferences.shraddhamReminderAdvanceMinutes) min",
                            value: $viewModel.draft.reminderPreferences.shraddhamReminderAdvanceMinutes,
                            in: 0...120, step: 5
                        )
                    }
                }
            } else {
                // Prompt to add death data to enable Śrāddham
                Text("Add death details to enable Śrāddham reminders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Export & Schedule", systemImage: "square.and.arrow.up")

            // ── Calendar & Reminders ─────────────────────────────────────────────
            // These buttons schedule events for ALL saved profiles (not just this draft).
            // Save the profile first, then use these to push to Apple Calendar / Reminders.
            VStack(alignment: .leading, spacing: 6) {
                Text("Schedule Events (All Profiles)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button {
                        Task { await viewModel.addToCalendar() }
                    } label: {
                        Label("Add to Apple Calendar", systemImage: "calendar.badge.plus")
                    }
                    .disabled(viewModel.days.isEmpty || viewModel.activeProfiles.isEmpty)
                    .help(viewModel.days.isEmpty
                          ? "Generate a Panchangam year first (use the Year stepper in the toolbar)"
                          : viewModel.activeProfiles.isEmpty
                            ? "Save at least one profile first"
                            : "Add birthday and Śrāddham events for all family profiles to Apple Calendar")

                    Button {
                        Task { await viewModel.addToReminders() }
                    } label: {
                        Label("Save to Reminders", systemImage: "bell.badge")
                    }
                    .disabled(viewModel.days.isEmpty || viewModel.activeProfiles.isEmpty)
                    .help(viewModel.days.isEmpty
                          ? "Generate a Panchangam year first"
                          : viewModel.activeProfiles.isEmpty
                            ? "Save at least one profile first"
                            : "Save family reminders to the Reminders tab and schedule notifications")
                }

                if viewModel.days.isEmpty {
                    Label("Generate a calendar year in the Calendar tab first.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

            Divider().padding(.vertical, 2)

            // ── Horoscope PDF — only for living persons ───────────────────────────
            if !viewModel.draft.isDeceased {
                HStack {
                    Button {
                        showPIIExportWarning = true
                    } label: {
                        Label("Export Horoscope PDF", systemImage: "square.and.arrow.up")
                    }
                    .disabled(viewModel.draft.birthDetails == nil)
                    .alert("Export Contains Personal Data", isPresented: $showPIIExportWarning) {
                        Button("Export Anyway") { showHoroscopeExport = true }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("The exported PDF will contain the person's full name, date of birth, birth location, and Grahanila chart. Share it only with trusted recipients.")
                    }

                    if viewModel.draft.birthDetails == nil {
                        Text("Requires birth details.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // ── Preview generated events for this profile ─────────────────────────
            Button {
                Task { await viewModel.previewEvents() }
            } label: {
                Label("Preview Calendar Events", systemImage: "calendar.badge.checkmark")
            }
            .disabled(viewModel.days.isEmpty)
            .help(viewModel.days.isEmpty ? "Generate a Panchangam year first" : "Preview birthday and Śrāddham dates for this profile")

            if !viewModel.previewBirthdayEvents.isEmpty || !viewModel.previewShraddhamEvents.isEmpty {
                eventsPreviewList
            }
        }
    }

    @ViewBuilder
    private var eventsPreviewList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Generated Events (\(viewModel.previewBirthdayEvents.count + viewModel.previewShraddhamEvents.count)):")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(viewModel.previewBirthdayEvents.prefix(5)) { evt in
                eventRow(evt, color: .green)
            }
            ForEach(viewModel.previewShraddhamEvents.prefix(5)) { evt in
                eventRow(evt, color: .orange)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func eventRow(_ event: CalendarEvent, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(event.title).font(.caption)
            Spacer()
            Text(event.startDate, style: .date).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Conflict Banner

    private var conflictBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(viewModel.pendingConflicts.count) calculated value(s) differ from your entries",
                  systemImage: "exclamationmark.triangle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.orange)

            ForEach(viewModel.pendingConflicts) { conflict in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(conflict.field.rawValue.capitalized): calculated \"\(conflict.calculatedDescription)\" vs entered \"\(conflict.enteredDescription)\"")
                        .font(.caption)

                    HStack(spacing: 8) {
                        Button("Keep Calculated") {
                            viewModel.resolveConflict(conflict, acceptCalculated: true)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)

                        Button("Keep Manual") {
                            viewModel.resolveConflict(conflict, acceptCalculated: false)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
                .padding(.leading, 12)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.top, 4)
    }

    // MARK: - Section Header Helper

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(.bottom, 4)
    }
}

// MARK: - LabeledTextField

private struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    var prompt: String = ""
    var axis: Axis = .horizontal
    /// Hard character limit. 0 = unlimited.
    var maxLength: Int = 0
    /// Optional inline validator: returns an error string or nil.
    var validate: ((String) -> String?)? = nil

    init(_ label: String,
         text: Binding<String>,
         prompt: String = "",
         axis: Axis = .horizontal,
         maxLength: Int = 0,
         validate: ((String) -> String?)? = nil) {
        self.label    = label
        self._text    = text
        self.prompt   = prompt
        self.axis     = axis
        self.maxLength = maxLength
        self.validate  = validate
    }

    private var validationError: String? { validate?(text) }
    private var overLimit: Bool { maxLength > 0 && text.count > maxLength }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            LabeledContent(label) {
                HStack(spacing: 4) {
                    TextField(prompt, text: $text, axis: axis)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(axis == .vertical ? 3 : 1)
                        .onChange(of: text) { _, newValue in
                            // Enforce hard length limit
                            if maxLength > 0 && newValue.count > maxLength {
                                text = String(newValue.prefix(maxLength))
                            }
                        }

                    if maxLength > 0 && text.count > maxLength - 20 {
                        Text("\(text.count)/\(maxLength)")
                            .font(.caption2)
                            .foregroundStyle(overLimit ? .red : .secondary)
                            .monospacedDigit()
                    }
                }
            }

            // Inline validation error
            if let error = validationError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.leading, 10)
            }
        }
    }
}

// MARK: - Input validators (free functions for reuse across form sections)

private func mobileValidator(_ s: String) -> String? {
    guard !s.isEmpty else { return nil }   // optional field
    let stripped = s.filter { $0.isNumber || $0 == "+" || $0 == "-" || $0 == " " }
    let digits   = s.filter(\.isNumber)
    if s != stripped {
        return "Only digits, +, -, and spaces are allowed."
    }
    if digits.count < 7 || digits.count > 15 {
        return "Phone number must have 7–15 digits."
    }
    return nil
}
