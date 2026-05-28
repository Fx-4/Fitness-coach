import SwiftUI

struct WeeklyBarChart: View {
    let samples: [DailyCalorieSample]
    let goal: Double

    private var maxValue: Double {
        max(samples.map(\.activeCalories).max() ?? 1, goal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("7-Day Active Calories")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(alignment: .bottom, spacing: DesignTokens.Spacing.xs) {
                ForEach(samples) { sample in
                    VStack(spacing: DesignTokens.Spacing.xs) {
                        let ratio = sample.activeCalories / maxValue
                        RoundedRectangle(cornerRadius: 4)
                            .fill(sample.activeCalories >= goal ? Color.green : Color.orange)
                            .frame(height: max(4, 80 * ratio))
                            .animation(.spring(response: 0.5), value: ratio)

                        Text(dayLabel(for: sample.date))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)

            HStack {
                Circle().fill(.green).frame(width: 8, height: 8)
                Text("Goal met").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Circle().fill(.orange).frame(width: 8, height: 8)
                Text("Below goal").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
    }

    private func dayLabel(for date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }
}
