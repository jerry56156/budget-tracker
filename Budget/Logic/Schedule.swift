import Foundation

enum Schedule {
    /// Every date of a repeating schedule that falls inside `month`.
    ///
    /// The schedule is `anchor`, `anchor ± frequencyDays`, `anchor ± 2 × frequencyDays`, ...
    /// It extends in both directions, so months before the stored "next" date work too.
    static func occurrences(anchor: Day, frequencyDays: Int, in month: MonthRef) -> [Day] {
        guard frequencyDays >= 1 else { return [] }
        let first = month.firstDay.ordinal
        let last = month.lastDay.ordinal
        let start = anchor.ordinal
        // Smallest k with start + k * frequency >= first, i.e. ceil((first - start) / frequency).
        var k = floorDivide(first - start + frequencyDays - 1, frequencyDays)
        var result: [Day] = []
        while start + k * frequencyDays <= last {
            result.append(Day(ordinal: start + k * frequencyDays))
            k += 1
        }
        return result
    }

    private static func floorDivide(_ a: Int, _ b: Int) -> Int {
        let q = a / b
        return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
    }
}
