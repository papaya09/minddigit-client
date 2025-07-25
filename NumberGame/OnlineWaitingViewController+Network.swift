import UIKit
import Foundation

// MARK: - Network Methods
extension OnlineWaitingViewController {
    
    func showPlayerNameDialog() {
        print("📝 Showing player name dialog")
        
        let alert = UIAlertController(title: "🌐 Join Online Game", 
                                    message: "Enter your player name to start", 
                                    preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Your Name"
            let savedName = UserDefaults.standard.string(forKey: "playerName") ?? ""
            textField.text = savedName.isEmpty ? "Player\(Int.random(in: 1...999))" : savedName
            textField.autocapitalizationType = .words
            textField.autocorrectionType = .no
        }
        
        alert.addAction(UIAlertAction(title: "Join Game", style: .default) { _ in
            if let name = alert.textFields?.first?.text, !name.trimmingCharacters(in: .whitespaces).isEmpty {
                let trimmedName = name.trimmingCharacters(in: .whitespaces)
                print("✅ Player name entered: '\(trimmedName)'")
                self.playerName = trimmedName
                UserDefaults.standard.set(trimmedName, forKey: "playerName")
                self.joinRoom()
            } else {
                print("❌ Empty player name, showing dialog again")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.showPlayerNameDialog()
                }
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            print("🚪 User cancelled joining")
            self.dismiss(animated: true)
        })
        
        // Check if view controller can present
        if presentedViewController == nil {
            present(alert, animated: true)
        } else {
            print("⚠️ Cannot present dialog - another view controller is already presented")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showPlayerNameDialog()
            }
        }
    }
    
    // MARK: - Enhanced Join Room with Cold Start Handling
    
    func joinRoom() {
        guard !playerName.isEmpty else { 
            print("❌ joinRoom: Player name is empty")
            return 
        }
        
        joinRetryCount = 0
        joinRoomWithRetry()
    }
    
    private func joinRoomWithRetry() {
        print("🚀 Join attempt \(joinRetryCount + 1)/\(maxJoinRetries) for: \(playerName)")
        print("🌐 Server URL: \(baseURL)")
        
        // Update UI for retry attempt
        DispatchQueue.main.async { [weak self] in
            self?.loadingSpinner.startAnimating()
            if self?.joinRetryCount == 0 {
                self?.statusLabel.text = "🔄 Connecting to server..."
            } else {
                self?.statusLabel.text = "🔄 Retrying... (\(self?.joinRetryCount ?? 0)/\(self?.maxJoinRetries ?? 3))"
            }
        }
        
        let url = URL(string: "\(baseURL)/room/join-local")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = 15.0 // Longer timeout for cold start
        
        let body = ["playerName": playerName]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ JSON encoding error:", error)
            DispatchQueue.main.async { [weak self] in
                self?.loadingSpinner.stopAnimating()
                self?.showError("Failed to prepare request: \(error.localizedDescription)")
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Handle network errors
            if let error = error {
                print("❌ Network error (attempt \(self.joinRetryCount + 1)): \(error.localizedDescription)")
                self.handleJoinFailure(error: "Network error: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                self.handleJoinFailure(error: "Invalid server response")
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                self.handleJoinFailure(error: "No data from server")
                return
            }
            
            print("📡 joinRoom HTTP Status: \(httpResponse.statusCode)")
            
            // Handle HTTP errors (including 500 from cold start)
            if httpResponse.statusCode != 200 {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Server error response: \(errorString)")
                
                // Specific handling for cold start errors
                if httpResponse.statusCode == 500 && errorString.contains("Internal Server Error") {
                    print("🧊 Detected Vercel cold start error - will retry")
                    self.handleJoinFailure(error: "Server starting up (cold start)")
                    return
                }
                
                self.handleJoinFailure(error: "Server error (\(httpResponse.statusCode))")
                return
            }
            
            // Print raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📨 joinRoom Response: \(responseString)")
            }
            
            // Parse successful response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let success = json["success"] as? Bool, success {
                        // Success! Extract room and player info
                        let roomId = json["roomId"] as? String ?? ""
                        let playerId = json["playerId"] as? String ?? ""
                        let position = json["position"] as? Int ?? 1
                        let gameState = json["gameState"] as? String ?? "WAITING"
                        
                        print("✅ Successfully joined room:")
                        print("   Room ID: \(roomId)")
                        print("   Player ID: \(playerId)")
                        print("   Position: \(position)")
                        print("   Game State: \(gameState)")
                        
                        DispatchQueue.main.async {
                            self.roomId = roomId
                            self.playerId = playerId
                            self.position = position
                            self.gameState = gameState
                            
                            // Save player info for recovery
                            UserDefaults.standard.set(playerId, forKey: "currentPlayerId")
                            UserDefaults.standard.set(roomId, forKey: "currentRoomId")
                            UserDefaults.standard.set(self.playerName, forKey: "currentPlayerName")
                            
                            self.loadingSpinner.stopAnimating()
                            self.roomIdLabel.text = "Room: \(roomId)"
                            self.updateUI(for: gameState)
                            self.setupSmartPolling()
                            self.showQuickStatus("✅ Room joined!")
                            
                            print("🎯 Join successful - ready for gameplay!")
                        }
                    } else {
                        let errorMsg = json["error"] as? String ?? "Unknown server error"
                        print("❌ Server reported error: \(errorMsg)")
                        self.handleJoinFailure(error: errorMsg)
                    }
                } else {
                    print("❌ Invalid JSON response")
                    self.handleJoinFailure(error: "Invalid server response format")
                }
            } catch {
                print("❌ JSON parsing error: \(error)")
                self.handleJoinFailure(error: "Failed to parse server response")
            }
        }.resume()
    }
    
    private func handleJoinFailure(error: String) {
        joinRetryCount += 1
        
        if joinRetryCount < maxJoinRetries {
            print("⏳ Retrying join in \(retryDelay) seconds (attempt \(joinRetryCount + 1)/\(maxJoinRetries))")
            
            // Retry after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                self?.joinRoomWithRetry()
            }
        } else {
            print("❌ Max join retries exceeded")
            
            DispatchQueue.main.async { [weak self] in
                self?.loadingSpinner.stopAnimating()
                self?.statusLabel.text = "❌ Connection failed"
                
                var errorMessage = "Failed to join room: \(error)"
                if error.contains("cold start") {
                    errorMessage += "\n\nThe server is starting up. Please try again in a moment."
                } else {
                    errorMessage += "\n\nPlease check your internet connection and try again."
                }
                
                self?.showError(errorMessage)
                self?.joinRetryCount = 0 // Reset for next attempt
            }
        }
    }
    
    func startPolling() {
        statusTimer?.invalidate()
        
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkRoomStatus()
        }
    }
    
    func stopPolling() {
        statusTimer?.invalidate()
        statusTimer = nil
    }
    
    func checkRoomStatus() {
        guard !roomId.isEmpty, !playerId.isEmpty else { 
            print("❌ checkRoomStatus: Missing roomId or playerId")
            showConnectionStatus(false)
            return 
        }
        
        let urlString = "\(baseURL)/room/status-local?roomId=\(roomId)&playerId=\(playerId)"
        print("🔍 Checking room status: \(urlString)")
        
        guard let url = URL(string: urlString) else { 
            print("❌ Invalid URL: \(urlString)")
            return 
        }
        
        var request = URLRequest(url: url)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Handle connection errors
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.showConnectionStatus(false)
                }
                return
            }
            
            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("❌ HTTP Error Response: \(errorString)")
                        
                        // Handle cold start gracefully for status checks
                        if httpResponse.statusCode == 500 && errorString.contains("Internal Server Error") {
                            print("🧊 Cold start detected in status check - will retry on next poll")
                        }
                    }
                    DispatchQueue.main.async {
                        self?.showConnectionStatus(false)
                    }
                    return
                }
            }
            
            guard let data = data else {
                print("❌ No data received")  
                DispatchQueue.main.async {
                    self?.showConnectionStatus(false)
                }
                return
            }
            
            // Print raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📨 Response: \(responseString)")
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ Failed to parse JSON")
                DispatchQueue.main.async {
                    self?.showConnectionStatus(false)
                }
                return
            }
            
            guard let success = json["success"] as? Bool, success else {
                print("❌ API returned success=false: \(json)")
                DispatchQueue.main.async {
                    self?.showConnectionStatus(false)
                }
                return
            }
            
            guard let room = json["room"] as? [String: Any] else {
                print("❌ No room data in response: \(json)")
                DispatchQueue.main.async {
                    self?.showConnectionStatus(false)
                }
                return
            }
            
            DispatchQueue.main.async {
                let newGameState = room["gameState"] as? String ?? "WAITING"
                let players = room["players"] as? [[String: Any]] ?? []
                let playerCount = room["currentPlayerCount"] as? Int ?? 0
                
                self?.updatePlayersDisplay(players)
                self?.showConnectionStatus(true)
                
                // Check if second player joined
                if playerCount == 2 && self?.gameState == "WAITING" {
                    self?.animatePlayerJoin()
                    self?.showQuickStatus("🎉 Player 2 joined!")
                }
                
                if newGameState != self?.gameState {
                    print("🔄 Game state changed: \(self?.gameState ?? "nil") → \(newGameState)")
                    self?.gameState = newGameState
                    self?.updateUI(for: newGameState)
                    self?.setupSmartPolling() // Adjust polling based on new state
                }
            }
        }.resume()
    }
    
    func selectDigits(_ digits: Int) {
        guard !roomId.isEmpty, !playerId.isEmpty else { 
            print("❌ selectDigits: Missing roomId or playerId")
            return 
        }
        
        print("🎯 Sending digit selection: \(digits) for room: \(roomId)")
        
        let url = URL(string: "\(baseURL)/game/select-digit")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "roomId": roomId,
            "playerId": playerId,
            "digits": digits
        ] as [String : Any]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                // Reset button state
                self?.actionButton.isEnabled = true
                self?.actionButton.setTitle("Confirm Selection", for: .normal)
                self?.loadingSpinner.stopAnimating()
            }
            
            if let error = error {
                print("❌ selectDigits error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.showError("Failed to send digit selection. Please try again.")
                }
                return
            }
            
            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 selectDigits HTTP Status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("❌ selectDigits error response: \(errorString)")
                    }
                    DispatchQueue.main.async {
                        self?.showError("Server error. Please try again.")
                    }
                    return
                }
            }
            
            guard let data = data else {
                print("❌ selectDigits: No response data")
                DispatchQueue.main.async {
                    self?.showError("No response from server. Please try again.")
                }
                return
            }
            
            // Print raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("📨 selectDigits Response: \(responseString)")
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool, success else {
                print("❌ selectDigits: Invalid response or success=false")
                DispatchQueue.main.async {
                    self?.showError("Failed to select digits. Please try again.")
                }
                return
            }
            
            DispatchQueue.main.async {
                let newGameState = json["gameState"] as? String ?? self?.gameState ?? "DIGIT_SELECTION"
                print("✅ selectDigits successful, new gameState: \(newGameState)")
                print("📱 Current gameState: \(self?.gameState ?? "nil"), new gameState: \(newGameState)")
                
                // Force update UI and gameState
                self?.gameState = newGameState
                self?.updateUI(for: newGameState)
                print("🔄 UI updated to state: \(newGameState)")
            }
        }.resume()
    }
    
    func setSecret() {
        guard let secretText = secretTextField.text, 
              !secretText.isEmpty,
              secretText.count == currentDigits,
              isValidSecret(secretText) else {
            showError("Please enter \(currentDigits) unique digits")
            return
        }
        
        let url = URL(string: "\(baseURL)/game/set-secret")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "roomId": roomId,
            "playerId": playerId,
            "secret": secretText
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        actionButton.isEnabled = false
        actionButton.setTitle("Setting...", for: .normal)
        loadingSpinner.startAnimating()
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.actionButton.isEnabled = true
                self?.loadingSpinner.stopAnimating()
                
                if let error = error {
                    self?.actionButton.setTitle("Set Secret", for: .normal)
                    self?.showError("Network error: \(error.localizedDescription)")
                    return
                }
                
                // Check HTTP response
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 setSecret HTTP Status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        if let data = data, let errorString = String(data: data, encoding: .utf8) {
                            print("❌ setSecret error response: \(errorString)")
                        }
                        self?.actionButton.setTitle("Set Secret", for: .normal)
                        self?.showError("Server error. Please try again.")
                        return
                    }
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let success = json["success"] as? Bool, success else {
                    self?.actionButton.setTitle("Set Secret", for: .normal)
                    
                    // Try to extract error message from response
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = json["error"] as? String {
                        self?.showError(errorMessage)
                    } else {
                        self?.showError("Failed to set secret")
                    }
                    return
                }
                
                print("✅ Secret set successfully")
                let newGameState = json["gameState"] as? String ?? self?.gameState ?? "SECRET_SETTING"
                print("🎯 New game state after setting secret: \(newGameState)")
                
                if newGameState != self?.gameState {
                    self?.gameState = newGameState
                    self?.updateUI(for: newGameState)
                } else {
                    // Still in SECRET_SETTING state, waiting for other player
                    self?.actionButton.setTitle("✅ Secret Set - Waiting...", for: .normal)
                    self?.actionButton.isEnabled = false
                    self?.secretTextField.isEnabled = false
                }
            }
        }.resume()
    }
    
    func leaveGame() {
        guard !roomId.isEmpty, !playerId.isEmpty else { return }
        
        let url = URL(string: "\(baseURL)/game/leave-local")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "roomId": roomId,
            "playerId": playerId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Fire and forget
        }.resume()
    }
    
    func navigateToGameplay() {
        stopPolling()
        
        let onlineGameVC = OnlineGameViewController()
        onlineGameVC.configure(roomId: roomId, playerId: playerId, digits: currentDigits)
        onlineGameVC.modalPresentationStyle = .fullScreen
        present(onlineGameVC, animated: true)
    }
    
    // MARK: - Helper Methods
    func isValidSecret(_ secret: String) -> Bool {
        guard secret.allSatisfy({ $0.isNumber }) else { return false }
        let digits = Set(secret)
        return digits.count == secret.count
    }
    
    func showError(_ message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
}