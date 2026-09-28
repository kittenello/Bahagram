#if arch(arm64) || arch(x86_64)
import ActivityKit
import DGSimpleSettings
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.2, iOS 16.2, *)
private struct DGDonutMark: View {
    let style: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(style == 0 ? Color.white : Color(red: 1, green: 0.58, blue: 0.70), lineWidth: 6)
            Circle()
                .stroke(style == 0 ? Color.white.opacity(0.5) : Color(red: 0.48, green: 0.23, blue: 0.12), lineWidth: 1)
                .padding(3)
            if style != 0 {
                ForEach(0 ..< 6, id: \.self) { index in
                    Capsule()
                        .fill(index.isMultiple(of: 2) ? Color.cyan : Color.yellow)
                        .frame(width: 3, height: 1.5)
                        .offset(y: -9)
                        .rotationEffect(.degrees(Double(index) * 60))
                }
            }
        }
        .frame(width: 21, height: 21)
    }
}

@available(iOSApplicationExtension 16.2, iOS 16.2, *)
struct DGIslandActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DGIslandActivityAttributes.self) { context in
            HStack(spacing: 9) {
                DGDonutMark(style: context.state.style)
                Text("DONUTGRAM").font(.headline)
            }
            .padding()
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 9) {
                        DGDonutMark(style: context.state.style)
                        Text(context.state.style == 1 ? "DONUT TIME" : "DONUTGRAM")
                            .font(.headline)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Ваши чаты рядом").font(.caption).foregroundColor(.secondary)
                }
            } compactLeading: {
                DGDonutMark(style: context.state.style)
            } compactTrailing: {
                Text(context.state.style == 2 ? "DG" : "DONUTGRAM")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(context.state.style == 1 ? .pink : .white)
            } minimal: {
                DGDonutMark(style: context.state.style)
            }
        }
    }
}
#endif
