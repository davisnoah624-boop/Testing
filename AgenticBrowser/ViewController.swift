import UIKit
import WebKit
import NaturalLanguage

class ViewController: UIViewController, WKNavigationDelegate, UITextFieldDelegate {

    var webView: WKWebView!
    var commandField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        let commandFieldHeight: CGFloat = 50

        commandField = UITextField()
        commandField.placeholder = "Enter your command"
        commandField.borderStyle = .roundedRect
        commandField.translatesAutoresizingMaskIntoConstraints = false
        commandField.delegate = self
        view.addSubview(commandField)

        NSLayoutConstraint.activate([
            commandField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            commandField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            commandField.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            commandField.heightAnchor.constraint(equalToConstant: commandFieldHeight)
        ])

        webView = WKWebView()
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: commandField.topAnchor, constant: -10)
        ])

        let url = URL(string: "https://www.google.com")!
        webView.load(URLRequest(url: url))
        webView.allowsBackForwardNavigationGestures = true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let command = textField.text {
            parseCommand(command)
        }
        textField.resignFirstResponder()
        return true
    }

    func parseCommand(_ command: String) {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = command

        var verb: String?
        var target: String?

        var verbFound = false

        tagger.enumerateTags(in: command.startIndex..<command.endIndex, unit: .word, scheme: .lexicalClass, options: []) { tag, tokenRange in
            if !verbFound {
                if let tag = tag, tag == .verb {
                    verb = String(command[tokenRange]).lowercased()

                    let targetStartIndex = command.index(after: tokenRange.upperBound)
                    if targetStartIndex < command.endIndex {
                        target = String(command[targetStartIndex...]).trimmingCharacters(in: .whitespaces)
                    }
                    verbFound = true
                    return false
                }
            }
            return true
        }

        if let verb = verb {
            switch verb {
            case "search":
                var searchTarget = target
                if let target = target, target.lowercased().starts(with: "for ") {
                    searchTarget = String(target.dropFirst(4))
                }
                if let searchTarget = searchTarget {
                     executeSearch(query: searchTarget)
                }
            case "click":
                 if let target = target {
                    let clickTarget = target.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    executeClick(linkText: clickTarget)
                }
            default:
                print("Unrecognized command verb: \(verb)")
                printLexicalTags(for: command)
            }
        } else {
            print("Could not find a verb in the command.")
            printLexicalTags(for: command)
        }
    }

    func printLexicalTags(for text: String) {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: []) { tag, tokenRange in
            if let tag = tag {
                let token = String(text[tokenRange])
                print("\(token): \(tag.rawValue)")
            }
            return true
        }
    }

    func executeSearch(query: String) {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.google.com/search?q=\(encodedQuery)") {
            webView.load(URLRequest(url: url))
        }
    }

    func executeClick(linkText: String) {
        let sanitizedLinkText = linkText.replacingOccurrences(of: "'", with: "\\'")
        let javascript = """
        var links = document.getElementsByTagName('a');
        var found = false;
        for (var i = 0; i < links.length; i++) {
            if (links[i].innerText.trim().toLowerCase() === '\(sanitizedLinkText.lowercased())') {
                links[i].click();
                found = true;
                break;
            }
        }
        """
        webView.evaluateJavaScript(javascript) { (result, error) in
            if let error = error {
                print("JavaScript error: \(error)")
            } else {
                print("Successfully evaluated JavaScript for click command.")
            }
        }
    }
}
