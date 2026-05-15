import SwiftUI

struct RemindersView: View {
    let days: [PanchangamDay]
    @Binding var duplicateNakshatraPolicy: DuplicateNakshatraPolicy
    @Binding var duplicateNakshatraThreshold: DuplicateNakshatraThreshold

    @State private var viewModel = ReminderViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if viewModel.isLoading {
                ProgressView("Loading reminders")
                    .controlSize(.small)
            }
            reminderList
            Divider()
            editor
            occurrencePanel
            actions
            preview
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .task {
            await viewModel.loadReminders()
            syncPolicy()
        }
        // Sync policy/threshold from CalendarViewModel whenever they change.
        .onChange(of: duplicateNakshatraPolicy) { _, _ in syncPolicy() }
        .onChange(of: duplicateNakshatraThreshold) { _, _ in syncPolicy() }
        // Recompute analysis whenever relevant draft fields change.
        .onChange(of: viewModel.draft.usesNakshatra)     { _, _ in refreshAnalysis() }
        .onChange(of: viewModel.draft.usesMalayalamMonth) { _, _ in refreshAnalysis() }
        .onChange(of: viewModel.draft.nakshatra)          { _, _ in refreshAnalysis() }
        .onChange(of: viewModel.draft.malayalamMonth)     { _, _ in refreshAnalysis() }
        .onChange(of: viewModel.duplicateNakshatraPolicy) { _, _ in refreshAnalysis() }
        .onChange(of: viewModel.duplicateNakshatraThreshold) { _, _ in refreshAnalysis() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("Reminders", systemImage: "bell")
                .font(.title3.weight(.semibold))
            Spacer()
            Button {
                viewModel.createReminder(location: days.first?.location ?? .thrissur)
                refreshAnalysis()
            } label: {
                Label("New", systemImage: "plus")
            }
            Button(role: .destructive) {
                viewModel.deleteSelectedReminder()
            } label: {
                Image(systemName: "trash")
            }
            .disabled(viewModel.selectedReminder == nil)
            .help("Delete selected reminder")
        }
    }

    // MARK: - List

    private var reminderList: some View {
        List(selection: $viewModel.selectedReminderID) {
            ForEach(viewModel.reminders) { reminder in
                VStack(alignment: .leading, spacing: 3) {
                    Text(reminder.name)
                    Text(reminderSummary(reminder))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(reminder.id)
                .onTapGesture {
                    viewModel.edit(reminder: reminder)
                    refreshAnalysis()
                }
            }
        }
        .frame(minHeight: 110, maxHeight: 140)
        .onChange(of: viewModel.selectedReminderID) { _, id in
            guard let id, let reminder = viewModel.reminders.first(where: { $0.id == id }) else { return }
            viewModel.edit(reminder: reminder)
            refreshAnalysis()
        }
    }

    // MARK: - Editor

    private var editor: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
            GridRow {
                Text("Name")
                    .foregroundStyle(.secondary)
                TextField("Event name", text: $viewModel.draft.name)
                    .textFieldStyle(.roundedBorder)
            }

            GridRow {
                Text("Type")
                    .foregroundStyle(.secondary)
                Picker("Type", selection: $viewModel.draft.kind) {
                    ForEach(ReminderKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
            }

            GridRow {
                Text("Match")
                    .foregroundStyle(.secondary)
                matchingRules
            }

            GridRow {
                Text("Time")
                    .foregroundStyle(.secondary)
                timePicker
            }
        }
    }

    // MARK: - Matching rules

    @ViewBuilder
    private var matchingRules: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── Nakshatra ────────────────────────────────────────────────
            Toggle("Nakshatra (birth star)", isOn: $viewModel.draft.usesNakshatra)
            if viewModel.draft.usesNakshatra {
                Picker("Nakshatra", selection: $viewModel.draft.nakshatra) {
                    ForEach(Nakshatra.allCases) { nakshatra in
                        Text(nakshatra.englishName).tag(nakshatra)
                    }
                }
                .padding(.leading, 16)

                // Month restriction — narrows to ~once per year for birthday/anniversary
                Toggle(isOn: $viewModel.draft.usesMalayalamMonth) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Restrict to Malayalam month")
                        Text("Matches only once per year — ideal for birthdays & anniversaries")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 16)
                .onChange(of: viewModel.draft.usesMalayalamMonth) { _, on in
                    // When month restriction is enabled, disable exact-date mode
                    if on { viewModel.draft.usesMalayalamDate = false }
                }

                if viewModel.draft.usesMalayalamMonth {
                    Picker("Month", selection: $viewModel.draft.malayalamMonth) {
                        ForEach(MalayalamMonth.allCases) { month in
                            Text(month.englishName).tag(month)
                        }
                    }
                    .padding(.leading, 32)
                }
            }

            Divider()

            // ── Exact Malayalam date ─────────────────────────────────────
            Toggle("Exact Malayalam date (month + day)", isOn: $viewModel.draft.usesMalayalamDate)
                .onChange(of: viewModel.draft.usesMalayalamDate) { _, on in
                    // Exact date and month restriction are mutually exclusive
                    if on { viewModel.draft.usesMalayalamMonth = false }
                }

            if viewModel.draft.usesMalayalamDate {
                HStack {
                    Picker("Month", selection: $viewModel.draft.malayalamMonth) {
                        ForEach(MalayalamMonth.allCases) { month in
                            Text(month.englishName).tag(month)
                        }
                    }
                    Stepper(value: $viewModel.draft.malayalamDay, in: 1...31) {
                        Text("Day \(viewModel.draft.malayalamDay)")
                            .monospacedDigit()
                    }
                }
                .padding(.leading, 16)
            }

            if let err = viewModel.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Time picker

    private var timePicker: some View {
        HStack {
            Stepper(value: $viewModel.draft.hour, in: 0...23) {
                Text(viewModel.draft.hour.formatted(.number.precision(.integerLength(2))))
                    .monospacedDigit()
                    .frame(width: 28, alignment: .trailing)
            }
            Text(":")
            Stepper(value: $viewModel.draft.minute, in: 0...55, step: 5) {
                Text(viewModel.draft.minute.formatted(.number.precision(.integerLength(2))))
                    .monospacedDigit()
                    .frame(width: 28, alignment: .trailing)
            }
            Picker("Lead", selection: $viewModel.draft.advanceMinutes) {
                Text("Exact").tag(0)
                Text("5 min before").tag(5)
                Text("15 min before").tag(15)
                Text("30 min before").tag(30)
                Text("1 hour before").tag(60)
            }
            .frame(maxWidth: 170)
        }
    }

    // MARK: - Occurrence analysis panel

    @ViewBuilder
    private var occurrencePanel: some View {
        if let analysis = viewModel.occurrenceAnalysis, analysis.isDuplicate || analysis.policy == .askEveryYear {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .foregroundStyle(.orange)
                    Text("\(analysis.nakshatra.englishName) appears \(analysis.occurrences.count)× in \(analysis.month?.englishName ?? "this month")")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    policyBadge(analysis.policy)
                }

                ForEach(analysis.occurrences) { occurrence in
                    OccurrenceRow(occurrence: occurrence, timeZone: days.first?.location.timeZone ?? .current)
                }

                if analysis.policy == .askEveryYear {
                    Label("All occurrences shown — choose manually each year.", systemImage: "hand.point.up.left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        } else if let analysis = viewModel.occurrenceAnalysis, !analysis.isEmpty {
            // Single occurrence — no conflict; show a compact reassurance row.
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .imageScale(.small)
                Text("\(analysis.nakshatra.englishName) appears once in \(analysis.month?.englishName ?? "this month") (\(analysis.occurrences.first?.durationLabel ?? ""))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func policyBadge(_ policy: DuplicateNakshatraPolicy) -> some View {
        Text(policy.title)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.15), in: Capsule())
            .foregroundStyle(.orange)
    }

    // MARK: - Actions

    private var actions: some View {
        HStack {
            Button {
                _ = viewModel.saveDraft()
            } label: {
                Label("Save", systemImage: "checkmark")
            }
            .disabled(!viewModel.canSaveDraft)

            Button {
                if let reminder = viewModel.saveDraft() {
                    Task { await viewModel.preview(reminder: reminder, days: days) }
                }
            } label: {
                Label("Preview", systemImage: "calendar.badge.clock")
            }
            .disabled(!viewModel.canSaveDraft)

            Button {
                if let reminder = viewModel.saveDraft() {
                    Task { await viewModel.export(reminder: reminder, days: days) }
                }
            } label: {
                Label("Add to Calendar", systemImage: "calendar.badge.plus")
            }
            .disabled(!viewModel.canSaveDraft)

            Button {
                if let reminder = viewModel.saveDraft() {
                    Task { await viewModel.scheduleAlerts(reminder: reminder, days: days) }
                }
            } label: {
                Label("Schedule Alerts", systemImage: "bell.badge")
            }
            .disabled(!viewModel.canSaveDraft)
        }
    }

    // MARK: - Preview results

    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.generatedEvents.isEmpty {
                Text("\(viewModel.generatedEvents.count) matching date(s) in generated year")
                    .font(.headline)
                ForEach(viewModel.generatedEvents.prefix(6)) { event in
                    HStack {
                        Text(event.title)
                        Spacer()
                        Text(event.startDate, style: .date)
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
                if viewModel.generatedEvents.count > 6 {
                    Text("+ \(viewModel.generatedEvents.count - 6) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func syncPolicy() {
        viewModel.duplicateNakshatraPolicy = duplicateNakshatraPolicy
        viewModel.duplicateNakshatraThreshold = duplicateNakshatraThreshold
        refreshAnalysis()
    }

    private func refreshAnalysis() {
        viewModel.refreshOccurrenceAnalysis(days: days)
    }

    private func reminderSummary(_ reminder: MalayalamReminder) -> String {
        var parts: [String] = [reminder.kind.title]
        if let star = reminder.nakshatra?.englishName { parts.append(star) }
        if let month = reminder.malayalamMonth?.englishName {
            if let day = reminder.malayalamDay {
                parts.append("\(month) \(day)")
            } else {
                parts.append(month)
            }
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Occurrence row

private struct OccurrenceRow: View {
    let occurrence: NakshatraOccurrence
    let timeZone: TimeZone

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Ordinal badge
            Text(occurrence.ordinalLabel)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .frame(width: 28)
                .padding(.vertical, 3)
                .background(
                    occurrence.isRecommended
                        ? Color.accentColor.opacity(0.15)
                        : Color.secondary.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            occurrence.isRecommended ? Color.accentColor.opacity(0.5) : Color.clear,
                            lineWidth: 1
                        )
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    // Duration
                    Text(occurrence.durationLabel)
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()

                    // Sunrise nakshatra indicator
                    if occurrence.isSunriseNakshatra {
                        Label("Active at sunrise", systemImage: "sunrise.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .labelStyle(.iconOnly)
                            .help("Active at sunrise on first day")
                    }

                    if occurrence.isRecommended {
                        Label("Recommended", systemImage: "checkmark.seal.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .labelStyle(.titleAndIcon)
                    }
                }

                // Date range
                if let first = occurrence.firstDay, let last = occurrence.lastDay {
                    let dateRange = first.isoDateKey == last.isoDateKey
                        ? first.isoDateKey
                        : "\(first.isoDateKey) – \(last.isoDateKey)"
                    Text(dateRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                // Transition times
                HStack(spacing: 12) {
                    if let inTime = occurrence.transitionInTime {
                        Label(PanchangamFormatters.time(inTime, timeZone: timeZone), systemImage: "arrow.right.circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let outTime = occurrence.transitionOutTime {
                        Label(PanchangamFormatters.time(outTime, timeZone: timeZone), systemImage: "arrow.left.circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Reasoning
                if !occurrence.reasoning.isEmpty {
                    Text(occurrence.reasoning)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
