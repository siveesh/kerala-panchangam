import AppKit
import Foundation
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - HoroscopeExporter

/// Generates a Kerala-style Jātakam PDF for a PersonProfile.
/// Draws the full South Indian 4×4 Grahanila chart grid using Core Text / CGContext.
@MainActor
struct HoroscopeExporter {

    // MARK: - Public API

    /// Shows an NSSavePanel so the user chooses where to save the PDF.
    /// Returns the chosen URL, or nil if the user cancelled.
    func exportPDF(
        for profile: PersonProfile,
        ayanamsa: AyanamsaSelection
    ) async throws -> URL? {
        // Always use fullName for the filename — never the nickname.
        let sanitised = profile.fullName
            .components(separatedBy: .whitespacesAndNewlines)
            .joined(separator: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        let defaultName = sanitised.isEmpty ? "Jatakam" : "\(sanitised)_Jatakam"

        let panel = NSSavePanel()
        panel.allowedContentTypes    = [UTType.pdf]
        panel.nameFieldStringValue   = "\(defaultName).pdf"
        panel.title                  = "Save Horoscope PDF"
        panel.message                = "Choose where to save \(profile.fullName)'s horoscope"
        panel.canCreateDirectories   = true

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return nil }

        let pdfData = buildPDF(for: profile, ayanamsa: ayanamsa)
        try pdfData.write(to: url, options: [.atomic])
        return url
    }

    // MARK: - PDF Assembly

    private func buildPDF(for profile: PersonProfile, ayanamsa: AyanamsaSelection) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)   // A4 portrait
        let mutableData = NSMutableData()
        guard let consumer = CGDataConsumer(data: mutableData as CFMutableData),
              var mediaBox = Optional(pageRect),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return Data() }

        ctx.beginPDFPage(nil)
        drawPage(for: profile, ayanamsa: ayanamsa, in: ctx, pageRect: pageRect)
        ctx.endPDFPage()
        ctx.closePDF()

        if let doc = PDFDocument(data: mutableData as Data) {
            return doc.dataRepresentation() ?? (mutableData as Data)
        }
        return mutableData as Data
    }

    // MARK: - Page Layout

    private func drawPage(
        for profile: PersonProfile,
        ayanamsa: AyanamsaSelection,
        in ctx: CGContext,
        pageRect: CGRect
    ) {
        let margin: CGFloat = 40
        let contentWidth = pageRect.width - margin * 2

        // White background
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(pageRect)

        var y: CGFloat = pageRect.height - 48

        // ── Title ────────────────────────────────────────────────────────────────
        // Always use fullName — never nickname — in the exported PDF.
        y = drawAttributedText(
            titleString(name: profile.fullName),
            x: margin, y: y, width: contentWidth, ctx: ctx)
        y -= 10
        drawHRule(ctx: ctx, x: margin, y: y, width: contentWidth)
        y -= 14

        // ── Birth Details / ജനനവിവരങ്ങൾ ─────────────────────────────────────────
        y = drawAttributedText(
            bilingualHeader("Birth Details", "ജനനവിവരങ്ങൾ", size: 13),
            x: margin, y: y, width: contentWidth, ctx: ctx)
        y -= 4

        if let birth = profile.birthDetails {
            let dobFmt = DateFormatter()
            dobFmt.dateStyle = .long
            dobFmt.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .current

            y = drawAttributedText(
                fieldLine("Date of Birth", "ജനനതീയതി",
                          value: dobFmt.string(from: birth.dateOfBirth)),
                x: margin, y: y, width: contentWidth, ctx: ctx)

            if let nak = birth.birthNakshatra {
                y = drawAttributedText(
                    fieldLine("Nakshatra", "നക്ഷത്രം",
                              value: "\(nak.englishName) · \(nak.malayalamName)"),
                    x: margin, y: y, width: contentWidth, ctx: ctx)
            }
            if let tithi = birth.birthTithi, let paksha = birth.birthPaksha {
                y = drawAttributedText(
                    fieldLine("Tithi", "തിഥി",
                              value: "\(paksha.shortName) \(tithi.englishName)"),
                    x: margin, y: y, width: contentWidth, ctx: ctx)
            }
            if let month = birth.birthMalayalamMonth,
               let day   = birth.birthMalayalamDay,
               let year  = birth.birthKollavarshamYear {
                y = drawAttributedText(
                    fieldLine("Malayalam Date", "മലയാളം തീയതി",
                              value: "\(month.englishName) \(day), \(year) K.E.  ·  \(month.malayalamName) \(day), \(year) കൊ.വ."),
                    x: margin, y: y, width: contentWidth, ctx: ctx)
            }
            if let loc = birth.birthLocation {
                y = drawAttributedText(
                    fieldLine("Birth Place", "ജനനസ്ഥലം", value: loc.name),
                    x: margin, y: y, width: contentWidth, ctx: ctx)
            }
            // Use the stored display hour/minute (timezone-independent) when available.
            // This eliminates any Mac-timezone vs birth-location-timezone ambiguity.
            // For profiles saved before this field was introduced, displayedBirthTime
            // falls back to formatting birthTime in TimeZone.current.
            if let timeStr = birth.displayedBirthTime {
                y = drawAttributedText(
                    fieldLine("Birth Time", "ജനനസമയം", value: timeStr),
                    x: margin, y: y, width: contentWidth, ctx: ctx)
            }
            if let lagna = birth.lagna {
                y = drawAttributedText(
                    fieldLine("Lagna (Ascendant)", "ലഗ്നം",
                              value: "\(lagna.englishName) · \(lagna.malayalamName)"),
                    x: margin, y: y, width: contentWidth, ctx: ctx)
            }
        } else {
            y = drawText("Birth details not entered.",
                         x: margin, y: y, width: contentWidth, fontSize: 11, bold: false, ctx: ctx)
        }

        // Optional personal fields
        if !profile.fatherName.isEmpty {
            y = drawAttributedText(
                fieldLine("Father's Name", "പിതാവ്", value: profile.fatherName),
                x: margin, y: y, width: contentWidth, ctx: ctx)
        }
        if !profile.motherName.isEmpty {
            y = drawAttributedText(
                fieldLine("Mother's Name", "മാതാവ്", value: profile.motherName),
                x: margin, y: y, width: contentWidth, ctx: ctx)
        }
        if !profile.mobileNumber.isEmpty {
            y = drawAttributedText(
                fieldLine("Mobile", "മൊബൈൽ", value: profile.mobileNumber),
                x: margin, y: y, width: contentWidth, ctx: ctx)
        }
        if !profile.address.isEmpty {
            y = drawAttributedText(
                fieldLine("Address", "വിലാസം", value: profile.address),
                x: margin, y: y, width: contentWidth, ctx: ctx)
        }
        y -= 10
        drawHRule(ctx: ctx, x: margin, y: y, width: contentWidth)
        y -= 14

        // ── Grahanila / ഗ്രഹനില ──────────────────────────────────────────────────
        y = drawAttributedText(
            bilingualHeader("Grahanila", "ഗ്രഹനില", size: 13),
            x: margin, y: y, width: contentWidth, ctx: ctx)
        y -= 8

        let grahanila = profile.birthGrahanila
        if grahanila.mode == .notSet {
            y = drawText("Chart not yet calculated or entered.",
                         x: margin, y: y, width: contentWidth, fontSize: 11, bold: false, ctx: ctx)
        } else {
            // Reduce chart to 78% of content width to leave room for the note below.
            let maxChartWidth = floor(contentWidth * 0.78)
            // Reserve enough space below the chart for the note line + footer.
            let footerReserve: CGFloat = 72
            let available = y - footerReserve

            let cellSize: CGFloat = min(floor(available / 4), floor(maxChartWidth / 4))
            let chartSize = cellSize * 4
            let chartLeft = margin + (contentWidth - chartSize) / 2

            drawGrahanilaChart(
                placements: grahanila.activePlacements,
                lagna: profile.birthDetails?.lagna,
                profile: profile,
                in: ctx,
                chartLeft: chartLeft,
                chartTop: y,
                cellSize: cellSize
            )
            y = y - chartSize - 12
        }

        // ── Note (bilingual) ──────────────────────────────────────────────────────
        // footerReserve guarantees y is safely above the footer stripe.
        y = drawAttributedText(
            noteString(),
            x: margin, y: y, width: contentWidth, ctx: ctx)

        // ── Footer (fixed at page bottom) ─────────────────────────────────────────
        drawText(
            "Exported from Siveesh's Calendar — \(ISO8601DateFormatter().string(from: Date()))",
            x: margin, y: 26, width: contentWidth, fontSize: 8, bold: false, ctx: ctx)
    }

    // MARK: - South Indian 4×4 Grahanila Grid

    /// South Indian chart: maps each Rasi to its (row, col) in a 4×4 grid (top-left origin).
    private static let rasiGrid: [(Rasi, row: Int, col: Int)] = [
        (.meenam,      0, 0), (.medam,      0, 1), (.edavam,    0, 2), (.mithunam,   0, 3),
        (.kumbham,     1, 0),                                           (.karkidakam, 1, 3),
        (.makaram,     2, 0),                                           (.chingam,    2, 3),
        (.dhanu,       3, 0), (.vrischikam, 3, 1), (.thulam,   3, 2), (.kanni,      3, 3)
    ]

    private func drawGrahanilaChart(
        placements: [RasiPlacement],
        lagna: Rasi?,
        profile: PersonProfile,
        in ctx: CGContext,
        chartLeft: CGFloat,
        chartTop: CGFloat,     // PDF y of chart TOP (highest y value)
        cellSize: CGFloat
    ) {
        // Build rasi → planets lookup
        var rasiPlanets: [Rasi: [RasiPlacement]] = [:]
        for p in placements { rasiPlanets[p.rasi, default: []].append(p) }

        ctx.setLineWidth(1.0)
        ctx.setStrokeColor(CGColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1))

        // 12 outer rasi cells
        for (rasi, row, col) in Self.rasiGrid {
            let rect = cellRect(row: row, col: col, left: chartLeft, top: chartTop, size: cellSize)
            ctx.stroke(rect)
            drawRasiCell(
                rasi: rasi,
                planets: rasiPlanets[rasi] ?? [],
                isLagna: lagna == rasi,
                in: ctx, rect: rect
            )
        }

        // Center 2×2 merged cell (rows 1-2, cols 1-2)
        let centerRect = CGRect(
            x: chartLeft + cellSize,
            y: chartTop - 3 * cellSize,   // bottom of the 2-row block in PDF coords
            width: 2 * cellSize,
            height: 2 * cellSize
        )
        ctx.stroke(centerRect)
        // Always use fullName in the chart center — never the nickname.
        drawCenterCell(profile: profile, lagna: lagna, in: ctx, rect: centerRect)
    }

    private func cellRect(row: Int, col: Int, left: CGFloat, top: CGFloat, size: CGFloat) -> CGRect {
        CGRect(
            x: left + CGFloat(col) * size,
            y: top - CGFloat(row + 1) * size,
            width: size,
            height: size
        )
    }

    // MARK: - Rasi Cell

    private func drawRasiCell(rasi: Rasi, planets: [RasiPlacement], isLagna: Bool, in ctx: CGContext, rect: CGRect) {
        if isLagna {
            ctx.setFillColor(CGColor(red: 0.93, green: 0.96, blue: 1.0, alpha: 1))
            ctx.fill(rect)
        }

        let pad: CGFloat = 4
        let rasiFont   = NSFont.systemFont(ofSize: 7, weight: .medium)
        let planetFont = mlFont(size: 11)
        let lagnaFont  = mlFont(size: 8)
        let grayColor  = CGColor(red: 0.45, green: 0.45, blue: 0.50, alpha: 1)
        let blackColor = CGColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1)
        let blueColor  = CGColor(red: 0.15, green: 0.35, blue: 0.75, alpha: 1)

        var baseline = rect.maxY - pad - ascender(of: rasiFont)
        drawLine(rasi.englishName, x: rect.minX + pad, baseline: baseline,
                 font: rasiFont, color: grayColor, ctx: ctx)
        baseline -= lineGap(of: rasiFont)

        // "ല" (Malayalam la, lagna marker) if lagna
        if isLagna {
            drawLine("ല", x: rect.minX + pad, baseline: baseline,
                     font: lagnaFont, color: blueColor, ctx: ctx)
            baseline -= lineGap(of: lagnaFont)
        }

        // Planet symbols — shortSymbol returns Malayalam abbreviations
        for placement in planets {
            guard baseline > rect.minY + pad else { break }
            let label = placement.planet.shortSymbol + (placement.isRetrograde ? "(R)" : "")
            drawLine(label, x: rect.minX + pad, baseline: baseline,
                     font: planetFont, color: blackColor, ctx: ctx)
            baseline -= lineGap(of: planetFont)
        }
    }

    // MARK: - Center Cell

    private func drawCenterCell(profile: PersonProfile, lagna: Rasi?, in ctx: CGContext, rect: CGRect) {
        ctx.setFillColor(CGColor(red: 0.97, green: 0.97, blue: 0.96, alpha: 1))
        ctx.fill(rect)

        let omFont     = NSFont.systemFont(ofSize: 22, weight: .bold)
        let nameFont   = NSFont.boldSystemFont(ofSize: 10)
        let detailFont = NSFont.systemFont(ofSize: 8)
        let redColor   = CGColor(red: 0.65, green: 0.10, blue: 0.10, alpha: 1)
        let blackColor = CGColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1)
        let grayColor  = CGColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 1)

        let lineHeights: [CGFloat] = [
            lineGap(of: omFont),
            lineGap(of: nameFont),
            lineGap(of: detailFont),
            lineGap(of: detailFont)
        ]
        let totalH = lineHeights.reduce(0, +)
        var baseline = rect.midY + totalH / 2 - ascender(of: omFont)

        drawLineCentered("ॐ", centerX: rect.midX, baseline: baseline,
                         font: omFont, color: redColor, ctx: ctx)
        baseline -= lineGap(of: omFont)

        // Always use fullName in the chart — never the nickname.
        drawLineCentered(profile.fullName, centerX: rect.midX, baseline: baseline,
                         font: nameFont, color: blackColor, ctx: ctx)
        baseline -= lineGap(of: nameFont)

        if let birth = profile.birthDetails {
            let fmt = DateFormatter()
            fmt.dateFormat = "dd MMM yyyy"
            fmt.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .current
            drawLineCentered(fmt.string(from: birth.dateOfBirth),
                             centerX: rect.midX, baseline: baseline,
                             font: detailFont, color: grayColor, ctx: ctx)
            baseline -= lineGap(of: detailFont)
        }

        if let loc = profile.birthDetails?.birthLocation {
            drawLineCentered(loc.name, centerX: rect.midX, baseline: baseline,
                             font: detailFont, color: grayColor, ctx: ctx)
        }
    }

    // MARK: - Bilingual NSAttributedString builders

    /// "Title — Malayalam Equivalent" in bold for section / page headings.
    private func titleString(name: String) -> NSAttributedString {
        let enFont = NSFont.boldSystemFont(ofSize: 20)
        let mlFont = mlFont(size: 18, bold: true)
        let s = NSMutableAttributedString()
        s.append(NSAttributedString(string: "\(name) — ", attributes: [.font: enFont, .foregroundColor: NSColor.black]))
        s.append(NSAttributedString(string: "ജാതകം", attributes: [.font: mlFont, .foregroundColor: NSColor.black]))
        s.append(NSAttributedString(string: " (Horoscope)", attributes: [.font: enFont, .foregroundColor: NSColor.black]))
        return s
    }

    /// Section header: "English · മലയാളം" bold.
    private func bilingualHeader(_ english: String, _ malayalam: String, size: CGFloat) -> NSAttributedString {
        let enFont  = NSFont.boldSystemFont(ofSize: size)
        let mlf     = mlFont(size: size, bold: true)
        let gray    = NSColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 1)
        let s = NSMutableAttributedString()
        s.append(NSAttributedString(string: english, attributes: [.font: enFont, .foregroundColor: NSColor.black]))
        s.append(NSAttributedString(string: " · \(malayalam)", attributes: [.font: mlf, .foregroundColor: gray]))
        return s
    }

    /// Field row: "[English Label] / [Malayalam Label]:  value"
    private func fieldLine(_ english: String, _ malayalam: String, value: String, size: CGFloat = 11) -> NSAttributedString {
        let labelFont = NSFont.boldSystemFont(ofSize: size - 0.5)
        let mlf       = mlFont(size: size - 0.5)
        let valFont   = NSFont.systemFont(ofSize: size)
        let gray      = NSColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1)
        let s = NSMutableAttributedString()
        s.append(NSAttributedString(string: english, attributes: [.font: labelFont, .foregroundColor: NSColor.black]))
        s.append(NSAttributedString(string: " / \(malayalam):  ", attributes: [.font: mlf, .foregroundColor: gray]))
        s.append(NSAttributedString(string: value, attributes: [.font: valFont, .foregroundColor: NSColor.black]))
        return s
    }

    /// Bilingual disclaimer note.
    private func noteString() -> NSAttributedString {
        let enFont = NSFont.systemFont(ofSize: 9)
        let mlf    = mlFont(size: 9)
        let gray   = NSColor(red: 0.50, green: 0.50, blue: 0.50, alpha: 1)
        let s = NSMutableAttributedString()
        s.append(NSAttributedString(string: "Note: ", attributes: [.font: NSFont.boldSystemFont(ofSize: 9), .foregroundColor: gray]))
        s.append(NSAttributedString(string: "This chart is an approximation. Verify with a qualified Jyotishi.  ", attributes: [.font: enFont, .foregroundColor: gray]))
        s.append(NSAttributedString(string: "· കുറിപ്പ്: ", attributes: [.font: NSFont(name: "MalayalamSangamMN", size: 9).map { $0 as NSFont } ?? NSFont.boldSystemFont(ofSize: 9), .foregroundColor: gray]))
        s.append(NSAttributedString(string: "ഈ ചാർട്ട് ഒരു ഏകദേശ കണക്കുകൂട്ടൽ ആണ്. ഒരു യോഗ്യനായ ജ്യോതിഷിയോടൊപ്പം സ്ഥിരീകരിക്കുക.", attributes: [.font: mlf, .foregroundColor: gray]))
        return s
    }

    // MARK: - Core Text drawing helpers

    @discardableResult
    private func drawAttributedText(
        _ attrStr: NSAttributedString,
        x: CGFloat, y: CGFloat,
        width: CGFloat,
        ctx: CGContext
    ) -> CGFloat {
        let fs = CTFramesetterCreateWithAttributedString(attrStr)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(
            fs, CFRangeMake(0, 0), nil,
            CGSize(width: width, height: .greatestFiniteMagnitude), nil)
        let rect = CGRect(x: x, y: y - size.height, width: width, height: size.height)
        let frame = CTFramesetterCreateFrame(fs, CFRangeMake(0, 0), CGPath(rect: rect, transform: nil), nil)
        ctx.saveGState()
        CTFrameDraw(frame, ctx)
        ctx.restoreGState()
        return y - size.height - 4
    }

    /// Draw a single line of text with baseline at (x, baseline) in PDF coords.
    private func drawLine(_ text: String, x: CGFloat, baseline: CGFloat,
                          font: NSFont, color: CGColor, ctx: CGContext) {
        guard let nsColor = NSColor(cgColor: color) else { return }
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: nsColor]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
        ctx.saveGState()
        ctx.textPosition = CGPoint(x: x, y: baseline)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    /// Draw a single line centred at centerX.
    private func drawLineCentered(_ text: String, centerX: CGFloat, baseline: CGFloat,
                                  font: NSFont, color: CGColor, ctx: CGContext) {
        guard let nsColor = NSColor(cgColor: color) else { return }
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: nsColor]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
        let w = CTLineGetTypographicBounds(line, nil, nil, nil)
        ctx.saveGState()
        ctx.textPosition = CGPoint(x: centerX - CGFloat(w) / 2, y: baseline)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    /// Horizontal rule
    private func drawHRule(ctx: CGContext, x: CGFloat, y: CGFloat, width: CGFloat) {
        ctx.saveGState()
        ctx.setStrokeColor(CGColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1))
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: x, y: y))
        ctx.addLine(to: CGPoint(x: x + width, y: y))
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Multi-line plain text helper (English-only, fallback)

    @discardableResult
    private func drawText(
        _ string: String,
        x: CGFloat, y: CGFloat,
        width: CGFloat,
        fontSize: CGFloat,
        bold: Bool,
        ctx: CGContext
    ) -> CGFloat {
        let font = bold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        return drawAttributedText(NSAttributedString(string: string, attributes: attrs),
                                  x: x, y: y, width: width, ctx: ctx)
    }

    // MARK: - Font helpers

    /// Malayalam-capable font with Latin fallback.
    private func mlFont(size: CGFloat, bold: Bool = false) -> NSFont {
        let names = bold
            ? ["MalayalamSangamMN-Bold", "MalayalamMN-Bold", "MalayalamSangamMN", "MalayalamMN"]
            : ["MalayalamSangamMN", "MalayalamMN"]
        for name in names {
            if let f = NSFont(name: name, size: size) { return f }
        }
        return bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
    }

    private func ascender(of font: NSFont) -> CGFloat { font.ascender }
    private func lineGap(of font: NSFont) -> CGFloat   { font.ascender - font.descender + 2 }
}
