import SwiftUI
import WebKit

func accountBadgeLabel(for normalizedType: String) -> String {
    switch normalizedType {
    case "alum":
        return "ALUM"
    case "subscriber":
        return "LAST.FM PRO"
    default:
        return normalizedType.uppercased()
    }
}

struct ProfileWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}

struct AnimatedAvatarImage: NSViewRepresentable {
    let urls: [URL]
    let size: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.enclosingScrollView?.drawsBackground = false
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(urls: urls, into: webView)
    }

    final class Coordinator {
        private var lastMarkup: String?

        func load(urls: [URL], into webView: WKWebView) {
            let candidates = urls.map(\.absoluteString)
            guard let data = try? JSONSerialization.data(withJSONObject: candidates),
                  let json = String(data: data, encoding: .utf8) else { return }

            // Use HTML img object-fit cover so avatar is cropped like native cover mode,
            // while still preserving GIF animation.
            let markup = """
            <html>
              <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                  html,body{margin:0;padding:0;overflow:hidden;background:transparent;width:100%;height:100%;}
                  #avatar{width:100%;height:100%;object-fit:cover;border-radius:50%;display:block;}
                </style>
              </head>
              <body>
                <img id="avatar" alt="" />
                <script>
                  const urls = \(json);
                  let i = 0;
                  const img = document.getElementById('avatar');
                  function next() {
                    if (i >= urls.length) return;
                    img.src = urls[i++];
                  }
                  img.onerror = next;
                  next();
                </script>
              </body>
            </html>
            """

            guard markup != lastMarkup else { return }
            lastMarkup = markup
            webView.loadHTMLString(markup, baseURL: nil)
        }
    }
}

struct AppBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let glyphWidth = min(proxy.size.width * 0.50, 860)
            let glyphHeight = glyphWidth * 0.62

            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [
                            Color(red: 0.10, green: 0.10, blue: 0.11),
                            Color(red: 0.05, green: 0.05, blue: 0.06)
                        ]
                        : [
                            Color(red: 0.97, green: 0.96, blue: 0.95),
                            Color(red: 0.93, green: 0.92, blue: 0.90)
                        ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: colorScheme == .dark
                        ? [Color(red: 0.83, green: 0.06, blue: 0.09).opacity(0.22), .clear]
                        : [Color(red: 0.83, green: 0.06, blue: 0.09).opacity(0.12), .clear],
                    center: .topLeading,
                    startRadius: 40,
                    endRadius: 520
                )
                .offset(x: -120, y: -80)

                RadialGradient(
                    colors: colorScheme == .dark
                        ? [Color.white.opacity(0.05), .clear]
                        : [Color.white.opacity(0.18), .clear],
                    center: .center,
                    startRadius: 40,
                    endRadius: 420
                )
                .offset(x: 220, y: -120)

                backdropGlyph(
                    color: colorScheme == .dark
                        ? Color(red: 0.83, green: 0.06, blue: 0.09).opacity(0.16)
                        : Color(red: 0.83, green: 0.06, blue: 0.09).opacity(0.09),
                    width: glyphWidth,
                    height: glyphHeight
                )
                .offset(x: -proxy.size.width * 0.10, y: -proxy.size.height * 0.08)

                backdropGlyph(
                    color: colorScheme == .dark
                        ? Color.white.opacity(0.04)
                        : Color.black.opacity(0.035),
                    width: glyphWidth * 0.92,
                    height: glyphHeight * 0.92
                )
                .offset(x: -proxy.size.width * 0.085, y: -proxy.size.height * 0.06)
            }
            .ignoresSafeArea()
        }
    }

    private func backdropGlyph(color: Color, width: CGFloat, height: CGFloat) -> some View {
        // Use a scalable text-based mark here instead of the 18x18 menu bar bitmap.
        // The tray asset is intentionally tiny; blowing it up for the app backdrop
        // creates visible pixelation on large windows.
        Text("as")
            .font(.custom("Avenir Next Heavy", size: width * 0.68))
            .italic()
            .tracking(-width * 0.035)
            .foregroundStyle(color)
            .frame(width: width, height: height, alignment: .center)
            .minimumScaleFactor(0.7)
            .blur(radius: colorScheme == .dark ? 24 : 20)
            .drawingGroup()
    }
}

struct HTMLSummaryText: View {
    let rawHTML: String
    let fontSize: CGFloat
    var lineLimit: Int? = nil

    var body: some View {
        Group {
            if let attributed = htmlSummaryAttributedString(from: rawHTML) {
                Text(attributed)
            } else {
                Text(rawHTML)
            }
        }
        .font(.custom("Avenir Next Regular", size: fontSize))
        .foregroundStyle(.secondary)
        .lineLimit(lineLimit)
        .tint(.accentColor)
        .textSelection(.enabled)
    }

    private func htmlSummaryAttributedString(from rawHTML: String) -> AttributedString? {
        guard let data = rawHTML.data(using: .utf8) else { return nil }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let nsAttributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil),
              let attributed = try? AttributedString(nsAttributed, including: AttributeScopes.FoundationAttributes.self) else {
            return nil
        }
        return attributed
    }
}

extension View {
    func appPanelStyle() -> some View {
        modifier(AppPanelModifier())
    }
}

private struct AppPanelModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding()
            .background(panelBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(panelBorder, lineWidth: 1)
            )
    }

    private var panelBackground: AnyShapeStyle {
        colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white.opacity(0.72))
    }

    private var panelBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }
}
