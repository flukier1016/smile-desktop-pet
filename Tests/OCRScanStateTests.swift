import Foundation

@main
enum OCRScanStateTests {
    static func main() {
        var state = OCRScanState()
        let first = state.begin()!
        precondition(state.begin() == nil, "Only one capture may run at a time")
        state.invalidate()
        state.invalidate()
        precondition(state.begin() == nil, "Invalidation must not open a second capture slot")
        precondition(!state.complete(first), "Cancelled OCR must never be accepted")
        precondition(state.inFlight == nil, "A cancelled completion must release its slot")
        let second = state.begin()!
        precondition(!state.complete(first), "A duplicate old callback must be ignored")
        precondition(state.inFlight == second, "Old callbacks must not release a newer capture")
        precondition(state.complete(second), "Current OCR must be accepted")
        precondition(!state.complete(second), "A result can only be accepted once")
        for _ in 0..<1000 {
            let request = state.begin()!
            state.invalidate()
            precondition(!state.complete(request))
        }
        let final = state.begin()!
        precondition(state.complete(final), "Rapid cancellation must not leave OCR stuck")
        print("OCR scan state: single-flight, cancellation, duplicate completion, and 1000 app switches passed")
    }
}
