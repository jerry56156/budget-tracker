import XCTest
@testable import Budget

final class ValidationTests: XCTestCase {
    func testValidAmounts() throws {
        XCTAssertEqual(try Validation.amount("12"), dec("12"))
        XCTAssertEqual(try Validation.amount("12.5"), dec("12.5"))
        XCTAssertEqual(try Validation.amount("12.50"), dec("12.5"))
        XCTAssertEqual(try Validation.amount("0.01"), dec("0.01"))
        XCTAssertEqual(try Validation.amount("  7  "), dec("7"))
        XCTAssertEqual(try Validation.amount("123456789012.99"), dec("123456789012.99"))
    }

    func testAmountsMustBePositive() {
        assertThrows(.notPositive) { try Validation.amount("0") }
        assertThrows(.notPositive) { try Validation.amount("0.00") }
    }

    func testAmountsCanHaveAtMostTwoDecimalPlaces() {
        assertThrows(.tooManyDecimals) { try Validation.amount("1.234") }
        assertThrows(.tooManyDecimals) { try Validation.amount("0.001") }
    }

    func testAmountsMustBePlainNumbers() {
        assertThrows(.empty) { try Validation.amount("") }
        assertThrows(.empty) { try Validation.amount("   ") }
        for text in ["abc", "-5", "+5", "1,000", "1.", ".5", "1e3", "1.2.3", "١٢", "12 50", "$12", "1\u{301}2"] {
            assertThrows(.notANumber) { try Validation.amount(text) }
        }
    }

    func testFrequencyMustBeAWholeNumberOfAtLeastOne() throws {
        XCTAssertEqual(try Validation.wholeDays("14"), 14)
        XCTAssertEqual(try Validation.wholeDays(" 1 "), 1)
        assertThrows(.empty) { try Validation.wholeDays("") }
        for text in ["0", "-1", "1.5", "two", "1234567"] {
            assertThrows(.notAWholeNumber) { try Validation.wholeDays(text) }
        }
    }

    func testDatesMustBeRealAndWrittenYearMonthDay() throws {
        XCTAssertEqual(try Validation.date("2025-02-28"), day("2025-02-28"))
        XCTAssertEqual(try Validation.date("2024-02-29"), day("2024-02-29"))
        assertThrows(.empty) { try Validation.date("") }
        for text in ["2025-02-30", "2025-02-29", "2025-13-01", "2025-00-10", "28/02/2025", "2025-2-8", "20250228", "tomorrow"] {
            assertThrows(.invalidDate) { try Validation.date(text) }
        }
    }

    func testMoneyText() {
        XCTAssertEqual(Money.plain(dec("12.50")), "12.5")
        XCTAssertEqual(Money.plain(dec("1234567.89")), "1234567.89")
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(Money.display(dec("1234.5"), symbol: "¤", locale: locale), "¤1,234.50")
        XCTAssertEqual(Money.display(dec("-20"), symbol: "¤", locale: locale), "-¤20.00")
        XCTAssertEqual(Money.display(dec("0"), symbol: "", locale: locale), "0.00")
        XCTAssertEqual(Money.display(dec("5"), symbol: "ABC ", locale: locale), "ABC 5.00")
    }
}
