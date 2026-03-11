import ActivityKit
import Foundation

// MARK: - Live Activity Attributes
public struct NavigationAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        // Dynamic content that updates (e.g. Turn instruction, ETA)
        public var currentInstruction: String
        public var nextInstruction: String?
        public var summaryText: String
        public var arrivalTimeText: String
        public var statusText: String
        public var etaSeconds: TimeInterval
        public var distanceMeters: Double
        public var progressValue: Double
        public var stepIndex: Int
        public var totalSteps: Int

        public init(
            currentInstruction: String,
            nextInstruction: String? = nil,
            summaryText: String,
            arrivalTimeText: String,
            statusText: String,
            etaSeconds: TimeInterval,
            distanceMeters: Double,
            progressValue: Double,
            stepIndex: Int,
            totalSteps: Int
        ) {
            self.currentInstruction = currentInstruction
            self.nextInstruction = nextInstruction
            self.summaryText = summaryText
            self.arrivalTimeText = arrivalTimeText
            self.statusText = statusText
            self.etaSeconds = etaSeconds
            self.distanceMeters = distanceMeters
            self.progressValue = progressValue
            self.stepIndex = stepIndex
            self.totalSteps = totalSteps
        }
    }

    // Static content (e.g. Destination Name)
    public var destinationName: String
    public var destinationDetail: String

    public init(destinationName: String, destinationDetail: String = "") {
        self.destinationName = destinationName
        self.destinationDetail = destinationDetail
    }
}
