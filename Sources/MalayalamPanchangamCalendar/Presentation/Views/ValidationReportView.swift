import SwiftUI

struct ValidationReportView: View {
    let day: PanchangamDay
    @State private var viewModel = ValidationReportViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Validation", systemImage: "checkmark.seal")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    Task { await viewModel.validate(day: day) }
                } label: {
                    if viewModel.isValidating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Validate", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(viewModel.isValidating)
            }

            if let result = viewModel.result {
                summary(result)
                rows(result)
            } else {
                Text("Run validation to compare this day with historical fixtures or configured online sources.")
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .onChange(of: day.id) { _, _ in
            viewModel.clear()
        }
    }

    private func summary(_ result: ValidationResult) -> some View {
        HStack(spacing: 12) {
            Image(systemName: result.passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(result.passed ? .green : .orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(result.passed ? "Passed" : "Needs Review")
                    .font(.headline)
                Text("\(result.sourceName) • Confidence \(Int(result.confidenceScore * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func rows(_ result: ValidationResult) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Text("Field").font(.caption.weight(.semibold))
                Text("Expected").font(.caption.weight(.semibold))
                Text("Calculated").font(.caption.weight(.semibold))
                Text("Delta").font(.caption.weight(.semibold))
                Text("").font(.caption)
            }
            Divider()
                .gridCellColumns(5)
            ForEach(ValidationReportFormatter.rows(for: result, timeZone: day.location.timeZone)) { row in
                GridRow {
                    Text(row.label)
                    Text(row.expected)
                        .foregroundStyle(.secondary)
                    Text(row.calculated)
                    Text(row.delta)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    statusIcon(row.passed)
                }
                .font(.callout)
            }
        }
    }

    @ViewBuilder
    private func statusIcon(_ passed: Bool?) -> some View {
        if let passed {
            Image(systemName: passed ? "checkmark.circle" : "xmark.circle")
                .foregroundStyle(passed ? .green : .red)
        } else {
            Image(systemName: "minus.circle")
                .foregroundStyle(.secondary)
        }
    }
}
