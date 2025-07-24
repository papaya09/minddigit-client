import UIKit

// MARK: - Network Methods
extension OnlineGameViewController {
    
    func startGamePolling() {
        stopGamePolling() // Stop any existing timer
        
        // Initial fetch
        fetchGameState()
        fetchGameHistory()
        
        // Start polling every 2 seconds
        gameTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchGameState()
        }
    }
    
    func stopGamePolling() {
        gameTimer?.invalidate()
        gameTimer = nil
    }
    
    func fetchGameState() {
        guard !roomId.isEmpty, !playerId.isEmpty else { return }
        
        // Use room status endpoint instead - it has currentTurn info
        let urlString = "\(baseURL)/room/status-local?roomId=\(roomId)&playerId=\(playerId)"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool, success else {
                return
            }
            
            DispatchQueue.main.async {
                self?.processGameState(json)
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
        // Process room data from status-local endpoint
        guard let room = json["room"] as? [String: Any] else {
            print("❌ No room data in response")
            return
        }
        
        // Update game state on main thread ONLY
        var roomIdFromResponse = ""
        var secretText = ""
        var shouldUpdateTurn = false
        var newCurrentTurn = ""
        
        // Collect all data first (no UI access)
        if let newGameState = room["gameState"] as? String {
            gameState = newGameState
        }
        
        roomIdFromResponse = room["id"] as? String ?? ""
        
        // Update player info and find digits (no UI access)
        if let players = room["players"] as? [[String: Any]] {
            for player in players {
                if let playerId = player["id"] as? String,
                   playerId == self.playerId {
                    
                    // Update digits if available
                    if let selectedDigits = player["selectedDigits"] as? Int {
                        self.digits = selectedDigits
                    }
                    
                    // Update secret if available
                    if let secret = player["secret"] as? String {
                        self.yourSecret = secret
                        secretText = secret
                    }
                    break
                }
            }
        }
        
        // Update game turn - check room level currentTurn (no UI access)
        if let currentTurnFromServer = room["currentTurn"] as? String {
            print("🎯 Server currentTurn: '\(currentTurnFromServer)', My ID: '\(playerId)'")
            if currentTurnFromServer != currentTurn {
                currentTurn = currentTurnFromServer
                isMyTurn = (currentTurn == playerId)
                shouldUpdateTurn = true
                newCurrentTurn = currentTurnFromServer
                print("🎯 Turn updated: isMyTurn = \(isMyTurn)")
            }
        } else {
            print("⚠️ No currentTurn in server response")
        }
        
        // ALL UI updates in single main thread dispatch
        DispatchQueue.main.async {
            // Ensure view is loaded before accessing UI elements
            guard self.isViewLoaded else {
                print("⚠️ View not loaded yet, skipping UI updates")
                return
            }
            
            // Update room label - with safe unwrapping
            if let roomLabel = self.roomLabel, roomLabel.superview != nil {
                roomLabel.text = "Room: \(roomIdFromResponse)"
            } else {
                print("⚠️ roomLabel is nil or not in view hierarchy")
            }
                
            // Update secret label - with comprehensive safety checks
            if !secretText.isEmpty {
                if let secretLabel = self.secretLabel, secretLabel.superview != nil {
                    secretLabel.text = "Your Secret: \(secretText)"
                    print("✅ Updated secret label: \(secretText)")
                } else {
                    print("⚠️ secretLabel is nil or not in view hierarchy, secretText: '\(secretText)'")
                    // Try to access secretLabel to see if it exists
                    print("⚠️ secretLabel exists: \(self.secretLabel != nil)")
                }
            }
            
            // Stop loading spinner
            if self.gameState == "PLAYING" || !self.currentTurn.isEmpty {
                if self.loadingSpinner.superview != nil {
                    self.loadingSpinner.stopAnimating()
                }
            }
            
            // Update turn UI if needed
            if shouldUpdateTurn {
                self.updateTurnUI()
            }
        }
    }
    
    private func updateGameHistory(_ history: [[String: Any]]) {
        // Safely clear current history on main thread
        DispatchQueue.main.async {
            guard let historyContainer = self.historyContainer else {
                print("⚠️ History container not initialized")
                return
            }
            
            // Remove existing views safely
            for subview in historyContainer.arrangedSubviews {
                historyContainer.removeArrangedSubview(subview)
                subview.removeFromSuperview()
            }
            
            if history.isEmpty {
                // Add placeholder if no history
                let placeholderView = self.createPlaceholderView()
                historyContainer.addArrangedSubview(placeholderView)
            } else {
                // Add new entries
                for entry in history {
                    self.addHistoryEntry(entry)
                }
            }
            
            print("📜 History updated with \(history.count) entries")
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
}
