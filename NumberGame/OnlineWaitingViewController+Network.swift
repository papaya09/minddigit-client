import UIKit

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
    
    func joinRoom() {
        guard !playerName.isEmpty else { 
            print("❌ joinRoom: Player name is empty")
            return 
        }
        
        print("🚀 Joining room with player: \(playerName)")
        print("🌐 Server URL: \(baseURL)")
        
        let url = URL(string: "\(baseURL)/room/join-local")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0 // Add timeout
        
        let body = ["playerName": playerName]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        loadingSpinner.startAnimating()
        statusLabel.text = "Joining room..."
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.loadingSpinner.stopAnimating()
                
                if let error = error {
                    print("❌ joinRoom error: \(error.localizedDescription)")
                    self?.showError("Connection failed: \(error.localizedDescription)")
                    return
                }
                
                // Check HTTP response
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 joinRoom HTTP Status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        // Print error response body for debugging
                        if let data = data, let errorString = String(data: data, encoding: .utf8) {
                            print("❌ Server error response: \(errorString)")
                        }
                        self?.showError("Server error \(httpResponse.statusCode): Check logs for details")
                        return
                    }
                }
                
                guard let data = data else {
                    print("❌ joinRoom: No response data")
                    self?.showError("No response data")
                    return
                }
                
                // Print raw response
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📨 joinRoom Response: \(responseString)")
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = json["success"] as? Bool, success {
                        
                        self?.roomId = json["roomId"] as? String ?? ""
                        self?.playerId = json["playerId"] as? String ?? ""
                        self?.position = json["position"] as? Int ?? 1
                        self?.gameState = json["gameState"] as? String ?? "WAITING"
                        
                        print("✅ Successfully joined room:")
                        print("   Room ID: \(self?.roomId ?? "none")")
                        print("   Player ID: \(self?.playerId ?? "none")")
                        print("   Position: \(self?.position ?? 0)")
                        print("   Game State: \(self?.gameState ?? "none")")
                        
                        DispatchQueue.main.async {
                            self?.roomIdLabel.text = "Room: \(self?.roomId ?? "")"
                            self?.updateUI(for: self?.gameState ?? "WAITING")
                            self?.setupSmartPolling()
                            self?.showQuickStatus("✅ Room joined!")
                        }
                    } else {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            let errorMessage = json["error"] as? String ?? "Failed to join room"
                            self?.showError(errorMessage)
                        } else {
                            self?.showError("Failed to join room")
                        }
                    }
                } catch {
                    self?.showError("Invalid response format")
                }
            }
        }.resume()
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
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
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
                    print("❌ HTTP Error: \(httpResponse.statusCode)")
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
        
        let url = URL(string: "\(baseURL)/game/select-digit-local")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "roomId": roomId,
            "playerId": playerId,
            "digit": digits
        ] as [String : Any]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ selectDigits error: \(error.localizedDescription)")
                return
            }
            
            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 selectDigits HTTP Status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("❌ selectDigits error response: \(errorString)")
                    }
                    return
                }
            }
            
            guard let data = data else {
                print("❌ selectDigits: No response data")
                return
            }
            
            // Print raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("📨 selectDigits Response: \(responseString)")
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool, success else {
                print("❌ selectDigits: Invalid response or success=false")
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
        
        let url = URL(string: "\(baseURL)/game/set-secret-local")!
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
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.actionButton.isEnabled = true
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let success = json["success"] as? Bool, success else {
                    self?.actionButton.setTitle("🔐 Set Secret", for: .normal)
                    self?.showError("Failed to set secret")
                    return
                }
                
                let newGameState = json["gameState"] as? String ?? self?.gameState ?? "SECRET_SETTING"
                if newGameState != self?.gameState {
                    self?.updateUI(for: newGameState)
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