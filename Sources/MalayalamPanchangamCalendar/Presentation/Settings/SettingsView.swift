import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: CalendarViewModel

    var body: some View {
        Form {
            Section("Calendar") {
                Picker("Calculation Mode", selection: $viewModel.calculationMode) {
                    ForEach(CalculationMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Picker("Names", selection: $viewModel.languagePreference) {
                    Text("English").tag(LanguagePreference.english)
                    Text("Malayalam").tag(LanguagePreference.malayalam)
                    Text("Bilingual").tag(LanguagePreference.bilingual)
                }

                Toggle("24-Hour Time", isOn: $viewModel.uses24HourTime)

                Picker("Ayanamsa", selection: $viewModel.ayanamsaSelection) {
                    ForEach(AyanamsaSelection.allCases) { ayanamsa in
                        Text(ayanamsa.rawValue.capitalized).tag(ayanamsa)
                    }
                }
            }

            Section("Reminders & Events") {
                Toggle("Notifications", isOn: $viewModel.notificationsEnabled)
                Toggle("Apple Calendar Integration", isOn: $viewModel.calendarIntegrationEnabled)
            }

            Section {
                Picker("Policy", selection: $viewModel.duplicateNakshatraPolicy) {
                    ForEach(DuplicateNakshatraPolicy.allCases) { policy in
                        Text(policy.title).tag(policy)
                    }
                }

                if let explanation = policyExplanation {
                    Text(explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if viewModel.duplicateNakshatraPolicy == .preferSecondUnlessShort {
                    thresholdControls
                }
            } header: {
                Label("Duplicate Nakshatra", systemImage: "arrow.triangle.2.circlepath")
            } footer: {
                Text("When a nakshatra appears twice in the same Malayalam month, this policy decides which occurrence to use for reminders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Observance Mode", selection: $viewModel.shraddhamObservanceMode) {
                    ForEach(ShraddhamObservanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Text(viewModel.shraddhamObservanceMode.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Label("Śrāddham (Death Anniversary)", systemImage: "leaf")
            } footer: {
                Text("Controls how the annual Śrāddham date is found. Kerala traditional practice uses the death nakshatra day in the same Malayalam month.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Validation") {
                Picker("Strictness", selection: $viewModel.validationStrictness) {
                    ForEach(ValidationStrictness.allCases) { strictness in
                        Text(strictness.rawValue.capitalized).tag(strictness)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 480)
        .onChange(of: viewModel.calculationMode) { _, _ in viewModel.savePreferences() }
        .onChange(of: viewModel.languagePreference) { _, _ in viewModel.savePreferences() }
        .onChange(of: viewModel.notificationsEnabled) { _, _ in viewModel.savePreferences() }
        .onChange(of: viewModel.calendarIntegrationEnabled) { _, _ in viewModel.savePreferences() }
        .onChange(of: viewModel.validationStrictness) { _, _ in viewModel.savePreferences() }
        .onChange(of: viewModel.ayanamsaSelection) { _, _ in viewModel.savePreferences() }
        .onChange(of: viewModel.uses24HourTime) { _, _ in viewModel.savePreferences() }
        .onChange(of: viewModel.duplicateNakshatraPolicy) { _, _ in viewModel.savePreferences() }
        .onChange(of: viewModel.duplicateNakshatraThreshold) { _, _ in viewModel.savePreferences() }
        .onChange(of: viewModel.shraddhamObservanceMode) { _, _ in viewModel.savePreferences() }
    }

    // MARK: - Helpers

    private var policyExplanation: String? {
        viewModel.duplicateNakshatraPolicy.explanation
    }

    @ViewBuilder
    private var thresholdControls: some View {
        Picker("Threshold type", selection: $viewModel.duplicateNakshatraThreshold.kind) {
            Text("% of solar day").tag(DuplicateNakshatraThreshold.Kind.percentage)
            Text("Fixed hours").tag(DuplicateNakshatraThreshold.Kind.fixedHours)
        }
        .pickerStyle(.segmented)

        switch viewModel.duplicateNakshatraThreshold.kind {
        case .percentage:
            HStack {
                Text("Minimum duration")
                Spacer()
                Text("\(Int(viewModel.duplicateNakshatraThreshold.percentage * 100))% of solar day")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: $viewModel.duplicateNakshatraThreshold.percentage,
                in: 0.05...0.50,
                step: 0.05
            ) {
                Text("Threshold")
            } minimumValueLabel: {
                Text("5%").font(.caption)
            } maximumValueLabel: {
                Text("50%").font(.caption)
            }

        case .fixedHours:
            HStack {
                Text("Minimum duration")
                Spacer()
                Text(String(format: "%.1f hours", viewModel.duplicateNakshatraThreshold.hours))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: $viewModel.duplicateNakshatraThreshold.hours,
                in: 1...12,
                step: 0.5
            ) {
                Text("Threshold")
            } minimumValueLabel: {
                Text("1h").font(.caption)
            } maximumValueLabel: {
                Text("12h").font(.caption)
            }
        }
    }
}
