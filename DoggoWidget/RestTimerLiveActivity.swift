//
//  RestTimerLiveActivity.swift
//  DoggoWidget
//
//  Lock-screen / Dynamic Island countdown for the rest timer.
//
//  ─── ACTIVATION (one-time, in Xcode) ─────────────────────────────────────
//  1. File → New → Target… → Widget Extension
//     • Product Name: DoggoWidget
//     • UNCHECK "Include Configuration App Intent"
//     • Activate the scheme when prompted
//  2. Delete the template .swift files Xcode generated for the new target.
//  3. Add this folder's two files (DoggoWidgetBundle.swift,
//     RestTimerLiveActivity.swift) to the DoggoWidget target
//     (File Inspector → Target Membership).
//  4. Select Doggo_V2/Core/Common/Utilities/DoggoActivityAttributes.swift and
//     add DoggoWidget to its Target Membership (shared between app + widget).
//  5. Build & run the app target. Start a rest timer and lock the phone.
//
//  The app side (RestTimerManager) already starts/updates/ends the activity;
//  NSSupportsLiveActivities is already set in Doggo-V2-Info.plist.
//  ──────────────────────────────────────────────────────────────────────────

import ActivityKit
import WidgetKit
import SwiftUI

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DoggoActivityAttributes.self) { context in
            // MARK: Lock Screen
            HStack {
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundStyle(.cyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest Timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                        .font(.title2.bold())
                        .monospacedDigit()
                }

                Spacer()

                Text("💪")
                    .font(.title)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(.cyan)

        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                        .font(.title2)
                        .foregroundStyle(.cyan)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                        .font(.title.bold())
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Rest — then back to work")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.cyan)
            } compactTrailing: {
                Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.cyan)
            }
        }
    }
}
