import Foundation

let apiKey = "YOUR_HUGGING_FACE_API_KEY"
let url = URL(string: "https://api-inference.huggingface.co/models/gpt2")!

var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")

let body: [String: Any] = ["inputs": "Hello, I'm testing the API."]
request.httpBody = try! JSONSerialization.data(withJSONObject: body)

let semaphore = DispatchSemaphore(value: 0)

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    defer { semaphore.signal() }
    
    if let error = error {
        print("Error: \(error.localizedDescription)")
        return
    }
    
    if let httpResponse = response as? HTTPURLResponse {
        print("Status code: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200, let data = data {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let firstResult = json.first,
               let generatedText = firstResult["generated_text"] as? String {
                print("Success! Generated text: \(generatedText)")
            } else {
                print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            }
        } else if httpResponse.statusCode == 401 {
            print("Failed: Invalid API key")
        } else {
            print("Failed with status: \(httpResponse.statusCode)")
        }
    }
}

task.resume()
semaphore.wait()
