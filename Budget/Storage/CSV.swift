import Foundation

/// One parsed CSV record.
struct CSVRow: Equatable {
    /// 1-based line in the file where this record starts.
    let line: Int
    var fields: [String]
    /// True if a value on this row opens a quote that is never closed.
    var unterminatedQuote = false
}

/// A small RFC 4180-style CSV reader and writer.
///
/// - Fields may be wrapped in double quotes; inside quotes, `""` is a literal quote and
///   commas and line breaks are part of the field.
/// - LF, CRLF and CR line endings are all accepted.
/// - Blank lines are skipped.
/// - A quote that is opened but never closed is treated as ordinary text and the row is
///   flagged, so one bad row cannot swallow the rest of the file.
///
/// Works on Unicode scalars rather than characters so that a comma or quote followed by a
/// combining mark is still recognised.
enum CSV {
    private static let quote: Unicode.Scalar = "\""
    private static let comma: Unicode.Scalar = ","
    private static let lf: Unicode.Scalar = "\n"
    private static let cr: Unicode.Scalar = "\r"

    static func parse(_ text: String) -> [CSVRow] {
        var scalars = Array(text.unicodeScalars)
        if scalars.first == "\u{FEFF}" { scalars.removeFirst() }

        var rows: [CSVRow] = []
        var fields: [String] = []
        var field = String.UnicodeScalarView()
        var inQuotes = false
        var fieldQuoted = false
        var rowQuoted = false
        var rowUnterminated = false
        var line = 1
        var rowLine = 1
        var quoteStart = 0
        var lineAtQuote = 1
        var literalQuoteIndex = -1

        func endField() {
            fields.append(String(field))
            field = String.UnicodeScalarView()
            fieldQuoted = false
        }
        func endRow() {
            endField()
            let isBlank = fields.count == 1 && !rowQuoted
                && fields[0].trimmingCharacters(in: .whitespaces).isEmpty
            if !isBlank {
                rows.append(CSVRow(line: rowLine, fields: fields, unterminatedQuote: rowUnterminated))
            }
            fields = []
            rowQuoted = false
            rowUnterminated = false
        }

        var i = 0
        while true {
            if i >= scalars.count {
                guard inQuotes else { break }
                // The file ended inside a quoted value. Go back and read that opening quote
                // as ordinary text, so only this row is affected.
                inQuotes = false
                fieldQuoted = false
                field = String.UnicodeScalarView()
                line = lineAtQuote
                literalQuoteIndex = quoteStart
                rowUnterminated = true
                i = quoteStart
                continue
            }
            let c = scalars[i]
            let nextIsLF = i + 1 < scalars.count && scalars[i + 1] == lf
            if inQuotes {
                if c == quote {
                    if i + 1 < scalars.count, scalars[i + 1] == quote {
                        field.append(quote)
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    // A CRLF pair is one line break; count it on the LF.
                    if c == lf || (c == cr && !nextIsLF) { line += 1 }
                    field.append(c)
                }
            } else if c == quote && field.isEmpty && !fieldQuoted && i != literalQuoteIndex {
                inQuotes = true
                fieldQuoted = true
                rowQuoted = true
                quoteStart = i
                lineAtQuote = line
            } else if c == comma {
                endField()
            } else if c == lf || c == cr {
                if c == cr && nextIsLF { i += 1 }
                endRow()
                line += 1
                rowLine = line
            } else {
                field.append(c)
            }
            i += 1
        }
        if !field.isEmpty || !fields.isEmpty || fieldQuoted {
            endRow()
        }
        return rows
    }

    static func encodeField(_ field: String) -> String {
        let scalars = field.unicodeScalars
        let needsQuotes = scalars.contains { $0 == comma || $0 == quote || $0 == lf || $0 == cr }
            || scalars.first?.properties.isWhitespace == true
            || scalars.last?.properties.isWhitespace == true
        guard needsQuotes else { return field }
        var out = String.UnicodeScalarView()
        out.append(quote)
        for scalar in scalars {
            if scalar == quote { out.append(quote) }
            out.append(scalar)
        }
        out.append(quote)
        return String(out)
    }

    static func encode(_ rows: [[String]]) -> String {
        rows.map { row -> String in
            // A lone empty value must be quoted or the line would read back as blank.
            if row.count == 1, row[0].trimmingCharacters(in: .whitespaces).isEmpty {
                return "\"" + row[0] + "\"\n"
            }
            return row.map(encodeField).joined(separator: ",") + "\n"
        }.joined()
    }
}
