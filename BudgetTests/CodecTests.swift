import XCTest
@testable import Budget

final class CodecTests: XCTestCase {
    // MARK: Expenses

    func testExpensesRoundTripIncludingAwkwardDescriptions() {
        let expenses = [
            expense("2025-01-05", "12.5", "Food", "Lunch, with \"friends\""),
            expense("2025-01-06", "3", "Fun", "two\nlines"),
            expense("2025-01-07", "0.01", "Food", ""),
        ]
        let decoded = ExpenseCodec.decode(ExpenseCodec.encode(expenses), file: "expenses.csv")
        XCTAssertEqual(rowValues(decoded.value), rowValues(expenses))
        XCTAssertTrue(decoded.warnings.isEmpty)
        XCTAssertTrue(decoded.preserved.isEmpty)
    }

    func testMalformedExpenseRowsAreReportedWithFileAndLineAndOthersAreKept() {
        let text = """
        date,amount,category,description
        2025-01-05,12.50,Food,"Lunch, with ""friends\"""
        2025-13-01,5,Food,bad date
        2025-01-06,abc,Food,bad amount
        2025-01-07,3.999,Food,too many decimals
        2025-01-08,4,Food
        2025-01-09,-2,Food,negative
        2025-01-10,7,Fun,ok
        """
        let decoded = ExpenseCodec.decode(text, file: "expenses.csv")

        XCTAssertEqual(rowValues(decoded.value), [
            ["2025-01-05", "12.5", "Food", "Lunch, with \"friends\""],
            ["2025-01-10", "7", "Fun", "ok"],
        ])
        XCTAssertEqual(decoded.warnings.map(\.line), [3, 4, 5, 6, 7])
        XCTAssertTrue(decoded.warnings.allSatisfy { $0.file == "expenses.csv" && !$0.message.isEmpty })
        XCTAssertEqual(decoded.preserved.count, 5)
        XCTAssertEqual(decoded.preserved[0], ["2025-13-01", "5", "Food", "bad date"])
    }

    func testMalformedRowsSurviveBeingWrittenBack() {
        let text = "date,amount,category,description\n2025-01-05,1,Food,ok\nnot,a,valid,row,at,all\n2025-99-99,1,Food,x\n"
        let first = ExpenseCodec.decode(text, file: "expenses.csv")
        let rewritten = ExpenseCodec.encode(first.value, preserved: first.preserved)
        let second = ExpenseCodec.decode(rewritten, file: "expenses.csv")

        XCTAssertEqual(rowValues(second.value), rowValues(first.value))
        XCTAssertEqual(second.preserved, first.preserved)
        XCTAssertEqual(second.warnings.count, 2)
        XCTAssertTrue(rewritten.contains("not,a,valid,row,at,all"))
        XCTAssertTrue(rewritten.contains("2025-99-99,1,Food,x"))
    }

    func testMissingHeaderMeansFirstRowIsData() {
        let decoded = ExpenseCodec.decode("2025-01-05,3,Food,x\n", file: "expenses.csv")
        XCTAssertEqual(rowValues(decoded.value), [["2025-01-05", "3", "Food", "x"]])
        XCTAssertTrue(decoded.warnings.isEmpty)
    }

    func testUnterminatedQuoteIsReportedOnItsLine() {
        let text = "date,amount,category,description\n2025-01-05,3,Food,\"oops\n2025-01-06,4,Food,fine\n"
        let decoded = ExpenseCodec.decode(text, file: "expenses.csv")
        XCTAssertEqual(rowValues(decoded.value), [["2025-01-06", "4", "Food", "fine"]])
        XCTAssertEqual(decoded.warnings.map(\.line), [2])
    }

    // MARK: Fixed items

    func testFixedItemsRoundTrip() {
        let items = [
            FixedItem(name: "Rent, flat 2", amount: dec("800"), frequencyDays: 30, nextDueDate: day("2025-01-01")),
            FixedItem(name: "Streaming", amount: dec("9.99"), frequencyDays: 7, nextDueDate: day("2025-01-05")),
        ]
        let decoded = FixedItemCodec.decode(FixedItemCodec.encode(items), file: "fixed_items.csv")
        XCTAssertEqual(decoded.value.map(\.name), ["Rent, flat 2", "Streaming"])
        XCTAssertEqual(decoded.value.map(\.amount), [dec("800"), dec("9.99")])
        XCTAssertEqual(decoded.value.map(\.frequencyDays), [30, 7])
        XCTAssertEqual(decoded.value.map(\.nextDueDate), [day("2025-01-01"), day("2025-01-05")])
        XCTAssertTrue(decoded.warnings.isEmpty)
    }

    func testMalformedFixedItemsAreReported() {
        let text = """
        name,amount,frequency_days,next_due_date
        Rent,800,30,2025-01-01
        ,5,7,2025-01-01
        Loan,5,0,2025-01-01
        Gym,5,7,tomorrow
        Phone,free,30,2025-01-01
        """
        let decoded = FixedItemCodec.decode(text, file: "fixed_items.csv")
        XCTAssertEqual(decoded.value.map(\.name), ["Rent"])
        XCTAssertEqual(decoded.warnings.map(\.line), [3, 4, 5, 6])
        XCTAssertTrue(decoded.warnings.allSatisfy { $0.file == "fixed_items.csv" })
        XCTAssertEqual(decoded.preserved.count, 4)
    }

    // MARK: Settings

    func testBlankSettingsFileIsIncompleteAndHasNoWarnings() {
        let decoded = SettingsCodec.decode(SettingsCodec.encode(Settings()), file: "settings.csv")
        XCTAssertEqual(decoded.value, Settings())
        XCTAssertFalse(decoded.value.isComplete)
        XCTAssertTrue(decoded.warnings.isEmpty)
    }

    func testSettingsRoundTrip() {
        var settings = Settings()
        settings.currencyCode = "ABC"
        settings.currencySymbol = "¤"
        settings.monthlyBudget = dec("1500.5")
        settings.payAmount = dec("2000")
        settings.payFrequencyDays = 14
        settings.nextPayDate = day("2025-01-03")
        settings.categories = ["Food", "Fun & games", "Transport"]

        let text = SettingsCodec.encode(settings)
        XCTAssertTrue(text.contains("categories,\"Food,Fun & games,Transport\"\n"))
        let decoded = SettingsCodec.decode(text, file: "settings.csv")
        XCTAssertEqual(decoded.value, settings)
        XCTAssertTrue(decoded.value.isComplete)
        XCTAssertTrue(decoded.warnings.isEmpty)
    }

    func testInvalidSettingsValuesAreReportedAndTreatedAsNotSet() {
        let text = """
        key,value
        currency,ABC
        monthly_budget,lots
        pay_frequency_days,0
        next_pay_date,2025-02-30
        categories,"Food, Fun ,Food"
        mystery,42
        just-one-field
        """
        let decoded = SettingsCodec.decode(text, file: "settings.csv")
        XCTAssertEqual(decoded.value.currencyCode, "ABC")
        XCTAssertNil(decoded.value.monthlyBudget)
        XCTAssertNil(decoded.value.payFrequencyDays)
        XCTAssertNil(decoded.value.nextPayDate)
        XCTAssertEqual(decoded.value.categories, ["Food", "Fun"])
        XCTAssertEqual(decoded.warnings.map(\.line), [3, 4, 5, 8])
        XCTAssertEqual(decoded.preserved, [["mystery", "42"], ["just-one-field"]])
    }

    func testUnknownSettingsRowsSurviveBeingWrittenBack() {
        let first = SettingsCodec.decode("key,value\ncurrency,ABC\nmystery,42\n", file: "settings.csv")
        let rewritten = SettingsCodec.encode(first.value, preserved: first.preserved)
        XCTAssertTrue(rewritten.contains("mystery,42\n"))
        XCTAssertEqual(SettingsCodec.decode(rewritten, file: "settings.csv").value.currencyCode, "ABC")
    }

    func testDisplaySymbolFallsBackToCurrencyCode() {
        var settings = Settings()
        XCTAssertEqual(settings.displaySymbol, "")
        settings.currencyCode = "ABC"
        XCTAssertEqual(settings.displaySymbol, "ABC ")
        settings.currencySymbol = "¤"
        XCTAssertEqual(settings.displaySymbol, "¤")
    }
}
