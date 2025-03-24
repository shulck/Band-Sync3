import UIKit
import PDFKit

class SetlistPDFExporter {
    // Method for creating PDF from setlist
    static func createPDF(from setlist: Setlist) -> Data? {
        // Set page size (8.5x11 inches)
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        // Create PDF renderer
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        // Generate PDF
        let pdfData = renderer.pdfData { context in
            // Create page
            context.beginPage()

            // Set fonts
            let titleFont = UIFont.boldSystemFont(ofSize: 24)
            let headerFont = UIFont.boldSystemFont(ofSize: 14)
            let textFont = UIFont.systemFont(ofSize: 12)

            // Margins
            let margin: CGFloat = 50
            var yPosition: CGFloat = margin

            // Draw setlist title
            let title = setlist.name
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]

            let titleString = NSAttributedString(string: title, attributes: titleAttributes)
            let titleStringSize = titleString.size()
            let titleRect = CGRect(
                x: (pageWidth - titleStringSize.width) / 2.0,
                y: yPosition,
                width: titleStringSize.width,
                height: titleStringSize.height
            )

            titleString.draw(in: titleRect)

            yPosition += titleStringSize.height + 20

            // Draw general information (number of songs, duration)
            let totalDuration = setlist.songs.reduce(0) { $0 + $1.duration }
            let minutes = Int(totalDuration) / 60
            let seconds = Int(totalDuration) % 60

            let infoText = "Total songs: \(setlist.songs.count) - Duration: \(minutes):\(String(format: "%02d", seconds))"
            let infoAttributes: [NSAttributedString.Key: Any] = [
                .font: headerFont,
                .foregroundColor: UIColor.black
            ]

            let infoString = NSAttributedString(string: infoText, attributes: infoAttributes)
            infoString.draw(at: CGPoint(x: margin, y: yPosition))

            yPosition += infoString.size().height + 15

            // Draw separator line
            context.cgContext.setStrokeColor(UIColor.gray.cgColor)
            context.cgContext.setLineWidth(1.0)
            context.cgContext.move(to: CGPoint(x: margin, y: yPosition))
            context.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            context.cgContext.strokePath()

            yPosition += 15

            // Draw table headers
            let headerText = "#    Song title                                                              Time"
            let headerString = NSAttributedString(string: headerText, attributes: infoAttributes)
            headerString.draw(at: CGPoint(x: margin, y: yPosition))

            yPosition += headerString.size().height + 5

            // Draw each song
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: textFont,
                .foregroundColor: UIColor.black
            ]

            for (index, song) in setlist.songs.enumerated() {
                let songMinutes = Int(song.duration) / 60
                let songSeconds = Int(song.duration) % 60
                let songDurationText = String(format: "%d:%02d", songMinutes, songSeconds)

                // Format string with song information
                let songText = String(format: "%3d  %@ %@", index + 1, song.title, songDurationText)
                let songString = NSAttributedString(string: songText, attributes: textAttributes)

                songString.draw(at: CGPoint(x: margin, y: yPosition))

                yPosition += songString.size().height + 10

                // Check if there is enough space on the page for the next song
                if yPosition > pageHeight - margin && index < setlist.songs.count - 1 {
                    // If not, start a new page
                    context.beginPage()
                    yPosition = margin
                }
            }

            // Draw date and time in footer
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short

            let footerText = "Created: \(dateFormatter.string(from: Date()))"
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 9),
                .foregroundColor: UIColor.gray
            ]

            let footerString = NSAttributedString(string: footerText, attributes: footerAttributes)
            let footerSize = footerString.size()

            footerString.draw(at: CGPoint(x: pageWidth - margin - footerSize.width,
                                        y: pageHeight - margin))
        }

        return pdfData
    }

    // Function to save PDF and open Share menu
    static func sharePDF(from setlist: Setlist, in viewController: UIViewController) {
        guard let pdfData = createPDF(from: setlist) else {
            print("Error creating PDF")
            return
        }

        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(setlist.name.replacingOccurrences(of: " ", with: "_")).pdf"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try pdfData.write(to: fileURL)

            // Create activity view controller for Share menu
            let activityViewController = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )

            // Set exclusions for iPad
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(x: viewController.view.bounds.midX,
                                          y: viewController.view.bounds.midY,
                                          width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            // Show Share menu
            viewController.present(activityViewController, animated: true)
        } catch {
            print("Error saving PDF: \(error.localizedDescription)")
        }
    }
}
