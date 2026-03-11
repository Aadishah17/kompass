@preconcurrency import ActivityKit
import Foundation

actor NavigationLiveActivityManager {
    static let shared = NavigationLiveActivityManager()

    private var activity: Activity<NavigationAttributes>?
    private var latestState: NavigationAttributes.ContentState?

    private init() {}

    nonisolated var areActivitiesAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(
        destinationName: String,
        destinationDetail: String,
        state: NavigationAttributes.ContentState
    ) async {
        latestState = state

        guard areActivitiesAvailable else { return }

        if activity != nil {
            await end(dismissalPolicy: .immediate)
            self.activity = nil
        }

        do {
            let attributes = NavigationAttributes(
                destinationName: destinationName,
                destinationDetail: destinationDetail
            )
            let content = ActivityContent(
                state: state,
                staleDate: Date().addingTimeInterval(max(state.etaSeconds, 60))
            )

            activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            print("Live Activity start failed: \(error.localizedDescription)")
        }
    }

    func update(state: NavigationAttributes.ContentState) async {
        latestState = state

        guard let activity, areActivitiesAvailable else { return }

        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(max(state.etaSeconds, 60))
        )

        await activity.update(content)
    }

    func end(dismissalPolicy: ActivityUIDismissalPolicy = .immediate) async {
        guard let activity else { return }

        let finalState = latestState ?? NavigationAttributes.ContentState(
            currentInstruction: "Navigation complete",
            nextInstruction: nil,
            summaryText: "Route complete",
            arrivalTimeText: "Now",
            statusText: "Ended",
            etaSeconds: 0,
            distanceMeters: 0,
            progressValue: 1,
            stepIndex: 0,
            totalSteps: 1
        )
        let content = ActivityContent(state: finalState, staleDate: nil)

        await activity.end(content, dismissalPolicy: dismissalPolicy)
        self.activity = nil
    }
}
