import XCTest
@testable import Budget

final class CSVTests: XCTestCase {
    // MARK: Parser

    func testSimpleRowsAndLineNumbers() {
        let rows = CSV.parse("a,b,c\n1,2,3\n")
        XCTAssertEqual(rows.map(\.fields), [["a", "b", "c"], ["1", "2", "3"]])
        XCTAssertEqual(rows.map(\.line), [1, 2])
    }

    func testQuotedFieldWithCommasAndEscapedQuotes() {
        let rows = CSV.parse("2025-01-05,12.50,Food,\"Lunch, with \"\"friends\"\"\"\n")
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].fields, ["2025-01-05", "12.50", "Food", "Lunch, with \"friends\""])
    }

    func testLineBreakInsideQuotesStaysInFieldAndKeepsLineNumbersRight() {
        let rows = CSV.parse("a,\"line one\nline two\"\nb,c\n")
        XCTAssertEqual(rows.map(\.fields), [["a", "line one\nline two"], ["b", "c"]])
        XCTAssertEqual(rows.map(\.line), [1, 3])
    }

    func testAllLineEndingStyles() {
        let rows = CSV.parse("a,b\r\nc,d\re,f")
        XCTAssertEqual(rows.map(\.fields), [["a", "b"], ["c", "d"], ["e", "f"]])
        XCTAssertEqual(rows.map(\.line), [1, 2, 3])
    }

    func testCRLFInsideQuotesCountsAsOneLine() {
        let rows = CSV.parse("a,\"x\r\ny\"\r\nb,c")
        XCTAssertEqual(rows.map(\.fields), [["a", "x\r\ny"], ["b", "c"]])
        XCTAssertEqual(rows.map(\.line), [1, 3])
    }

    func testBlankLinesAreSkippedButStillCounted() {
        let rows = CSV.parse("a,b\n\n   \nc,d\n")
        XCTAssertEqual(rows.map(\.fields), [["a", "b"], ["c", "d"]])
        XCTAssertEqual(rows.map(\.line), [1, 4])
    }

    func testEmptyFields() {
        XCTAssertEqual(CSV.parse("a,,c\n,,\n").map(\.fields), [["a", "", "c"], ["", "", ""]])
    }

    func testTrailingCommaWithoutFinalNewline() {
        XCTAssertEqual(CSV.parse("a,b,").map(\.fields), [["a", "b", ""]])
    }

    func testQuotedEmptyValueIsARowNotABlankLine() {
        XCTAssertEqual(CSV.parse("\"\"\n").map(\.fields), [[""]])
    }

    func testQuoteInsideUnquotedFieldIsOrdinaryText() {
        XCTAssertEqual(CSV.parse("5\" nail,ab\"c\n").map(\.fields), [["5\" nail", "ab\"c"]])
    }

    func testUnterminatedQuoteIsFlaggedAndOnlyAffectsItsOwnRow() {
        let rows = CSV.parse("a,\"b\nc,d\n")
        XCTAssertEqual(rows.map(\.fields), [["a", "\"b"], ["c", "d"]])
        XCTAssertEqual(rows.map(\.unterminatedQuote), [true, false])
        XCTAssertEqual(rows.map(\.line), [1, 2])
    }

    func testByteOrderMarkIsIgnored() {
        XCTAssertEqual(CSV.parse("\u{FEFF}a,b\n").map(\.fields), [["a", "b"]])
    }

    func testEmptyTextHasNoRows() {
        XCTAssertTrue(CSV.parse("").isEmpty)
        XCTAssertTrue(CSV.parse("\n\n").isEmpty)
    }

    func testCommaFollowedByCombiningMarkStillSeparates() {
        XCTAssertEqual(CSV.parse("a,\u{301}b\n").map(\.fields), [["a", "\u{301}b"]])
    }

    // MARK: Writer

    func testWriterQuotesOnlyWhenNeeded() {
        XCTAssertEqual(CSV.encodeField("plain"), "plain")
        XCTAssertEqual(CSV.encodeField(""), "")
        XCTAssertEqual(CSV.encodeField("a,b"), "\"a,b\"")
        XCTAssertEqual(CSV.encodeField("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(CSV.encodeField("two\nlines"), "\"two\nlines\"")
        XCTAssertEqual(CSV.encodeField(" padded"), "\" padded\"")
    }

    func testWriterEndsEveryRowWithNewline() {
        XCTAssertEqual(CSV.encode([["a", "b"], ["c", "d"]]), "a,b\nc,d\n")
        XCTAssertEqual(CSV.encode([]), "")
    }

    func testRoundTripOfAwkwardValues() {
        let rows = [
            ["plain", "with,comma", "with \"quotes\"", "multi\nline", " spaced ", "", "\u{301}accent", "crlf\r\nvalue"],
            [""],
            ["\"", ",", "\"\"", "a\"b,c\"d"],
            ["日本語", "emoji 🎉", "tab\there"],
        ]
        XCTAssertEqual(CSV.parse(CSV.encode(rows)).map(\.fields), rows)
    }
}
