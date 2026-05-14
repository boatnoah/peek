import SwiftUI

struct PreviewCardView: View {
    let result: EnrichmentResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if result.title != nil || result.faviconURL != nil {
                HStack(spacing: 8) {
                    if let faviconURL = result.faviconURL {
                        AsyncImage(url: faviconURL) { image in
                            image
                                .resizable()
                                .frame(width: 16, height: 16)
                        } placeholder: {
                            Color.clear
                                .frame(width: 16, height: 16)
                        }
                    }

                    if let title = result.title {
                        Text(title)
                            .font(.headline)
                            .lineLimit(2)
                    }
                }
            }

            if let description = result.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(result.resolvedDomain)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            trustBadgeView
        }
        .padding(12)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 2)
        )
    }

    @ViewBuilder private var trustBadgeView: some View {
        switch result.trustBadge {
        case .verified:
            Label("Verified", systemImage: "checkmark.shield.fill")
                .font(.caption)
                .foregroundStyle(.green)

        case .mismatch:
            Label("Domain mismatch", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)

        case .shortener(let resolvedDomain):
            Label("Shortened URL → \(resolvedDomain)", systemImage: "arrow.triangle.branch")
                .font(.caption)
                .foregroundStyle(.orange)

        case .knownRisk:
            Label("Known risk", systemImage: "xmark.shield.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}
