import Foundation

struct HealthInterpreter {
    func interpret(current: SystemSnapshot, processes: [ProcessSnapshot], history: [HistoryPoint]) -> InterpretedHealth {
        let score = HealthScorer.evaluate(snapshot: current, processes: processes, history: history)
        let reasons = ExplanationGenerator.generate(level: score.level, signals: score.signals, snapshot: current)
        return InterpretedHealth(
            level: score.level,
            summary: ExplanationGenerator.summary(for: score.level),
            reasons: reasons,
            signals: score.signals
        )
    }
}
