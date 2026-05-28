import SwiftUI

struct CalorieRingView: View {
    let progress: Double       // 0–1
    let burned: String
    let goal: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.orange.opacity(0.15), lineWidth: DesignTokens.Ring.strokeWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [.orange, .pink],
                        center: .center
                    ),
                    style: StrokeStyle(
                        lineWidth: DesignTokens.Ring.strokeWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8), value: progress)

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(burned)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                Text("of \(goal) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: DesignTokens.Ring.size, height: DesignTokens.Ring.size)
    }
}

struct CalorieRingView_Previews: PreviewProvider {
    static var previews: some View {
        CalorieRingView(progress: 0.65, burned: "325", goal: "500")
            .padding()
    }
}
