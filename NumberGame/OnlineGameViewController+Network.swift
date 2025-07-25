import UIKit

// MARK: - Network Methods
extension OnlineGameViewController {
    
    // MARK: - Enhanced Network Layer with Recovery
    
    func startGamePolling() {
        retryCount = 0
        isRecovering = false
        gameTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchGameStateWithRetry()
        }
        
        // Immediate fetch
        fetchGameStateWithRetry()
        print("🔄 Started game polling with enhanced recovery")
    }
    
    func stopGamePolling() {
        gameTimer?.invalidate()
        gameTimer = nil
        retryCount = 0
        isRecovering = false
        print("⏹️ Stopped game polling and reset recovery state")
    }
    
    private func fetchGameStateWithRetry() {
        // Prevent multiple concurrent requests during recovery
        guard !isRecovering else {
            print("🚧 Skipping fetch - recovery in progress")
            return
        }
        
        fetchGameState { [weak self] success in
            if success {
                self?.retryCount = 0
                self?.isRecovering = false
            } else {
                self?.handleFetchFailure()
            }
        }
    }
    
    private func handleFetchFailure() {
        retryCount += 1
        print("⚠️ Fetch failed (attempt \(retryCount)/\(maxRetries))")
        
        if retryCount >= maxRetries {
            print("🔄 Starting recovery mode")
            isRecovering = true
            
            // Use last successful response as fallback
            if let lastResponse = lastSuccessfulResponse {
                print("📦 Using cached response for recovery")
                processGameState(lastResponse)
            }
            
            // Show recovery message to user
            DispatchQueue.main.async { [weak self] in
                self?.showRecoveryMessage()
            }
            
            // Reset retry count for next attempt
            retryCount = 0
            
            // Schedule recovery attempt
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                self?.isRecovering = false
                print("✅ Recovery mode ended, resuming normal polling")
            }
        }
    }
    
    private func showRecoveryMessage() {
        // Create a subtle recovery indicator
        let recoveryLabel = UILabel()
        recoveryLabel.text = "🔄 Reconnecting..."
        recoveryLabel.font = UIFont.systemFont(ofSize: 12)
        recoveryLabel.textColor = UIColor.systemOrange
        recoveryLabel.textAlignment = .center
        recoveryLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(recoveryLabel)
        NSLayoutConstraint.activate([
            recoveryLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            recoveryLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        // Auto-remove after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            recoveryLabel.removeFromSuperview()
        }
    }
    
    func fetchGameState(completion: ((Bool) -> Void)? = nil) {
        let url = "\(baseURL)/room/status-local"
        let parameters = [
            "roomId": roomId,
            "playerId": playerId
        ]
        
        var urlComponents = URLComponents(string: url)!
        urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = 10.0 // Shorter timeout for better responsiveness
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { 
                completion?(false)
                return 
            }
            
            if let error = error {
                print("❌ Network error:", error.localizedDescription)
                completion?(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                completion?(false)
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                completion?(false)
                return
            }
            
            if httpResponse.statusCode != 200 {
                print("❌ HTTP Error:", httpResponse.statusCode)
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Error response:", errorString)
                }
                completion?(false)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📡 Status response received")
                    
                    // Cache successful response
                    self.lastSuccessfulResponse = json
                    
                    // Validate response has required fields
                    if json["success"] as? Bool == true {
                        self.processGameState(json)
                        completion?(true)
                    } else {
                        print("⚠️ Server reported error:", json["error"] as? String ?? "Unknown")
                        
                        // Check if this is a recoverable error
                        if let recovery = json["recovery"] as? Bool, recovery {
                            print("🔄 Server indicated recovery mode")
                            // Still process the response for state recovery
                            self.processGameState(json)
                            completion?(true)
                        } else {
                            completion?(false)
                        }
                    }
                } else {
                    print("❌ Invalid JSON format")
                    completion?(false)
                }
            } catch {
                print("❌ JSON parsing error:", error)
                completion?(false)
            }
        }.resume()
    }
    
    func fetchGameHistory() {
        guard !roomId.isEmpty, !playerId.isEmpty else { return }
        
        let urlString = "\(baseURL)/game/history-local?roomId=\(roomId)&playerId=\(playerId)"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool, success,
                  let history = json["history"] as? [[String: Any]] else {
                return
            }
            
            DispatchQueue.main.async {
                self?.updateGameHistory(history)
                
                // Check for winner
                if let winner = json["winner"] as? [String: Any],
                   let winnerPlayerId = winner["playerId"] as? String {
                    if winnerPlayerId == self?.playerId {
                        self?.showWinDialog()
                    } else {
                        self?.showLoseDialogNetwork(winnerName: winner["playerName"] as? String ?? "Opponent")
                    }
                }
            }
        }.resume()
    }
    
    private func processGameState(_ json: [String: Any]) {
        // Process room data from status-local endpoint with enhanced error handling
        guard let room = json["room"] as? [String: Any] else {
            print("❌ No room data in response")
            return
        }
        
        // Check for server-side validation issues
        if let validation = json["validation"] as? [String: Any],
           let isValid = validation["valid"] as? Bool, !isValid {
            let reason = validation["reason"] as? String ?? "Unknown validation error"
            print("⚠️ Server validation failed: \(reason)")
            
            // Show validation error to user but continue processing for recovery
            DispatchQueue.main.async { [weak self] in
                self?.showValidationError(reason)
            }
        }
        
        // Check for recovery suggestions
        if let suggestion = json["suggestion"] as? String {
            print("💡 Server suggestion: \(suggestion)")
        }
        
        // Check for next action guidance
        if let nextAction = json["nextAction"] as? String {
            print("➡️ Next action: \(nextAction)")
        }
        
        // Collect data without UI access first
        var shouldUpdateUI = false
        var shouldUpdateTurn = false
        var newGameState = ""
        var roomIdFromResponse = ""
        var secretText = ""
        var newCurrentTurn = ""
        
        // Update game state with validation
        if let serverGameState = room["gameState"] as? String {
            if serverGameState != gameState {
                let oldState = gameState
                gameState = serverGameState
                newGameState = serverGameState
                shouldUpdateUI = true
                print("🎮 Game state changed: \(oldState) → \(serverGameState)")
                
                // Add state-specific feedback
                switch serverGameState {
                case "PLAYING":
                    print("🎯 Game is now active - ready for guesses!")
                case "WAITING":
                    print("⏳ Waiting for players to join")
                case "DIGIT_SELECTION":
                    print("🔢 Time to select number of digits")
                case "SECRET_SETTING":
                    print("🔐 Time to set secret numbers")
                case "FINISHED":
                    print("🏁 Game has ended")
                default:
                    break
                }
            }
        }
        
        roomIdFromResponse = room["id"] as? String ?? roomId
        
        // Update player info with better error handling
        if let players = room["players"] as? [[String: Any]] {
            for player in players {
                if let playerId = player["id"] as? String, playerId == self.playerId {
                    // Update digits
                    if let selectedDigits = player["selectedDigits"] as? Int, selectedDigits != self.digits {
                        self.digits = selectedDigits
                        shouldUpdateUI = true
                        print("🔢 Updated digits to: \(selectedDigits)")
                    }
                    
                    // Update secret (but protect player-set secrets)
                    if let secret = player["secret"] as? String, !secret.isEmpty {
                        // Only update if we don't have a secret yet, or if it's clearly player-set
                        if self.yourSecret.isEmpty {
                            // No secret yet, accept from server
                            self.yourSecret = secret
                            secretText = secret
                            shouldUpdateUI = true
                            print("🔐 Received secret from server: \(secret)")
                        } else if self.yourSecret != secret {
                            // We have a different secret - check if server one looks auto-generated
                            if isAutoGeneratedSecret(secret) {
                                print("⚠️ Ignoring auto-generated secret from server: \(secret), keeping player secret: \(self.yourSecret)")
                            } else if isValidPlayerSecret(secret, digits: self.digits) {
                                // Server secret looks valid and player-set, update it
                                print("🔄 Updating to new player secret: \(self.yourSecret) → \(secret)")
                                self.yourSecret = secret
                                secretText = secret
                                shouldUpdateUI = true
                            } else {
                                print("❌ Rejecting invalid secret from server: \(secret)")
                            }
                        }
                    }
                    break
                }
            }
        }
        
        // Enhanced turn management with validation
        if let serverCurrentTurn = room["currentTurn"] as? String {
            if serverCurrentTurn != currentTurn {
                let oldTurn = currentTurn
                print("🔄 Turn changed: '\(oldTurn)' → '\(serverCurrentTurn)'")
                currentTurn = serverCurrentTurn
                isMyTurn = (currentTurn == playerId)
                newCurrentTurn = serverCurrentTurn
                shouldUpdateTurn = true
                shouldUpdateUI = true
                
                // Add turn feedback
                if isMyTurn {
                    print("✅ It's YOUR turn!")
                } else {
                    print("⏳ Waiting for opponent's turn")
                }
            }
        }
        
        // Process any additional metadata
        if let serverTime = json["serverTime"] as? TimeInterval {
            let localTime = Date().timeIntervalSince1970 * 1000
            let timeDiff = abs(localTime - serverTime)
            if timeDiff > 5000 { // 5 seconds
                print("⏰ Time drift detected: \(timeDiff)ms")
            }
        }
        
        // Apply all UI updates in a single batch on main thread
        if shouldUpdateUI || shouldUpdateTurn {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if shouldUpdateUI {
                    // Update secret label if we have secret text
                    if !secretText.isEmpty {
                        self.secretLabel.text = "🔐 SECURITY CODE: \(secretText)"
                    }
                }
                
                if shouldUpdateTurn {
                    self.updateTurnUI()
                }
                
                // Update keypad state
                self.updateKeypadButtonsState()
            }
        }
        
        // Fetch history if we're in playing state for real-time updates
        if gameState == "PLAYING" {
            fetchGameHistory()
        }
    }
    
    private func updateGameHistory(_ history: [[String: Any]]) {
        // More sensitive comparison using actual content
        let historySignature = createHistorySignature(history)
        
        // Only update UI if history actually changed
        guard historySignature != lastHistoryHash else {
            print("📜 History unchanged, skipping UI update")
            return
        }
        
        print("📜 History changed: \(lastHistoryHash) → \(historySignature)")
        lastHistoryHash = historySignature
        
        // Safely update history on main thread
        DispatchQueue.main.async {
            guard let historyContainer = self.historyContainer else {
                print("⚠️ History container not initialized")
                return
            }
            
            // Always rebuild for reliability (optimize later if needed)
            self.rebuildHistoryView(with: history, container: historyContainer)
        }
    }
    
    private func createHistorySignature(_ history: [[String: Any]]) -> Int {
        // Create more detailed signature including content and order
        var signature = ""
        
        for (index, entry) in history.enumerated() {
            signature += "\(index):"
            signature += (entry["playerName"] as? String ?? "") + "|"
            signature += (entry["guess"] as? String ?? "") + "|"
            signature += "\(entry["bulls"] as? Int ?? 0)" + "|"
            signature += "\(entry["cows"] as? Int ?? 0)" + "|"
            signature += (entry["timestamp"] as? String ?? "") + ";"
        }
        
        return signature.hashValue
    }
    
    private func rebuildHistoryView(with history: [[String: Any]], container: UIStackView) {
        // Remove existing views safely
        for subview in container.arrangedSubviews {
            container.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        
        if history.isEmpty {
            // Add placeholder if no history
            let placeholderView = self.createPlaceholderView()
            container.addArrangedSubview(placeholderView)
            print("📜 Added placeholder - no game history yet")
        } else {
            // Add new entries in order
            for (index, entry) in history.enumerated() {
                self.addHistoryEntry(entry)
                print("📜 Added history entry \(index + 1): \(entry["guess"] as? String ?? "?") by \(entry["playerName"] as? String ?? "?")")
            }
        }
        
        print("📜 History view rebuilt with \(history.count) entries")
        
        // Auto-scroll to bottom to show latest moves
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let scrollView = container.superview as? UIScrollView {
                let bottomOffset = CGPoint(x: 0, y: max(0, scrollView.contentSize.height - scrollView.bounds.height))
                scrollView.setContentOffset(bottomOffset, animated: true)
            }
        }
    }
    
    private func showLoseDialogNetwork(winnerName: String) {
        stopGamePolling()
        
        let alert = UIAlertController(title: "😔 Game Over", 
                                    message: "\(winnerName) won this round!\n\nBetter luck next time!", 
                                    preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Back to Menu", style: .default) { _ in
            self.dismiss(animated: true)
        })
        
        present(alert, animated: true)
        
        // Failure haptic feedback
        let failureFeedback = UINotificationFeedbackGenerator()
        failureFeedback.notificationOccurred(.error)
    }
    
    // MARK: - Secret Protection Helpers
    private func isAutoGeneratedSecret(_ secret: String) -> Bool {
        // Auto-generated secrets from server tend to have certain patterns
        // 1. Often start with higher digits (due to hash + 1000)
        // 2. May have patterns that are unlikely for humans to choose
        
        guard secret.count >= 3 else { return false }
        
        // Check if secret starts with high digits (common in auto-generation)
        if secret.hasPrefix("1") || secret.hasPrefix("2") || secret.hasPrefix("3") {
            // Further check for patterns typical of hash-based generation
            let digits = secret.compactMap { Int(String($0)) }
            
            // Auto-generated often have large jumps between consecutive digits
            for i in 0..<digits.count-1 {
                let diff = abs(digits[i] - digits[i+1])
                if diff >= 5 { // Large jump suggests auto-generation
                    return true
                }
            }
        }
        
        // Check for specific patterns that our generateDeterministicSecret creates
        // (4-digit numbers starting from 1000-9999 range)
        if secret.count == 4, let number = Int(secret) {
            return number >= 1000 && number <= 9999
        }
        
        return false
    }
    
    private func isValidPlayerSecret(_ secret: String, digits: Int) -> Bool {
        // Check if secret looks like something a player would set
        guard secret.count == digits else { return false }
        guard secret.allSatisfy({ $0.isNumber }) else { return false }
        
        // Check for unique digits
        let uniqueDigits = Set(secret)
        guard uniqueDigits.count == secret.count else { return false }
        
        // Player-set secrets often have simpler patterns
        // Like: 1234, 5678, 1357, etc.
        return true
    }
    
    private func showValidationError(_ reason: String) {
        // Show a subtle, non-blocking error indicator
        let errorView = UIView()
        errorView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        errorView.layer.cornerRadius = 8
        errorView.translatesAutoresizingMaskIntoConstraints = false
        
        let errorLabel = UILabel()
        errorLabel.text = "⚠️ \(reason)"
        errorLabel.font = UIFont.systemFont(ofSize: 12)
        errorLabel.textColor = UIColor.systemRed
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        
        errorView.addSubview(errorLabel)
        view.addSubview(errorView)
        
        NSLayoutConstraint.activate([
            errorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            errorView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            errorView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            errorLabel.topAnchor.constraint(equalTo: errorView.topAnchor, constant: 8),
            errorLabel.bottomAnchor.constraint(equalTo: errorView.bottomAnchor, constant: -8),
            errorLabel.leadingAnchor.constraint(equalTo: errorView.leadingAnchor, constant: 12),
            errorLabel.trailingAnchor.constraint(equalTo: errorView.trailingAnchor, constant: -12)
        ])
        
        // Auto-remove after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            errorView.removeFromSuperview()
        }
    }
}
