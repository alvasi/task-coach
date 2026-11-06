import Foundation

/// Optional: with a personal Linear API key, assigned in-progress tickets show up even
/// before any Claude session has touched them.
enum LinearClient {
    private static let query = """
    query {
      viewer {
        assignedIssues(first: 25, orderBy: updatedAt,
          filter: { state: { type: { in: ["started", "unstarted"] } } }) {
          nodes {
            identifier title description url
            state { name }
            comments(first: 8) { nodes { body } }
          }
        }
      }
    }
    """

    static func fetchAssigned(apiKey: String) async throws -> [LinearIssue] {
        var request = URLRequest(url: URL(string: "https://api.linear.app/graphql")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query])

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "Linear", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Linear returned HTTP \(http.statusCode)"])
        }
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let errors = root?["errors"] as? [[String: Any]], let first = errors.first?["message"] as? String {
            throw NSError(domain: "Linear", code: 0, userInfo: [NSLocalizedDescriptionKey: first])
        }
        let nodes = (((root?["data"] as? [String: Any])?["viewer"] as? [String: Any])?["assignedIssues"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []
        return nodes.compactMap { n in
            guard let id = n["identifier"] as? String, let title = n["title"] as? String else { return nil }
            let comments = ((n["comments"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []).compactMap { $0["body"] as? String }
            return LinearIssue(identifier: id, title: title, description: n["description"] as? String,
                               url: n["url"] as? String, stateName: (n["state"] as? [String: Any])?["name"] as? String,
                               comments: comments)
        }
    }
}
