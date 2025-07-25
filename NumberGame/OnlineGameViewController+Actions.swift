import UIKit

// MARK: - Actions & Game Logic
extension OnlineGameViewController {
    
    @objc func keypadNumberTapped(_ sender: UIButton) {
        // Only allow input when it's my turn
        guard isMyTurn else {
            print("❌ Keypad blocked: Not your turn")
            // Visual feedback for blocked tap
            sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            UIView.animate(withDuration: 0.1) {
                sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }
            return
        }
        
        let number = sender.tag
        let currentText = guessTextField.text ?? ""
        
        // Check if we can add more digits
        guard currentText.count < digits else {
            print("❌ Maximum digits reached")
            // Visual feedback for max digits
            guessTextField.layer.borderColor = UIColor.systemRed.cgColor
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.guessTextField.layer.borderColor = UIColor.systemGreen.cgColor
            }
            return
        }
        
        // Add visual feedback for successful tap
        sender.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        UIView.animate(withDuration: 0.15, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            sender.transform = CGAffineTransform.identity
        }
        
        let newText = currentText + "\(number)"
        guessTextField.text = newText
        
        // Update submit button state
        guessTextChanged()
        
        // Visual feedback for text field update
        UIView.transition(with: guessTextField, duration: 0.2, options: .transitionCrossDissolve) {
            // Text updated above
        }
        
        print("🔢 Added digit: \(number) -> '\(newText)'")
    }
    
    @objc func clearTapped() {
        guard isMyTurn else {
            print("❌ Clear blocked: Not your turn")
            return
        }
        
        // Visual feedback for clear action
        UIView.transition(with: guessTextField, duration: 0.3, options: .transitionFlipFromLeft) {
            self.guessTextField.text = ""
        }
        
        guessTextChanged()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        print("🧹 Text cleared")
    }
    
    @objc func guessTextChanged() {
        // MUST be called from main thread
        assert(Thread.isMainThread, "guessTextChanged() must be called from main thread")
        
        let currentGuess = guessTextField.text ?? ""
        let isValidLength = (currentGuess.count == digits)
        
        // Enable submit button only if valid length AND it's my turn
        submitButton.isEnabled = isValidLength && isMyTurn
        submitButton.alpha = (isValidLength && isMyTurn) ? 1.0 : 0.5
        
        print("🔤 Guess text changed: '\(currentGuess)' (\(currentGuess.count)/\(digits)) - Valid: \(isValidLength), MyTurn: \(isMyTurn)")
        print("🎯 Submit button updated: enabled=\(submitButton.isEnabled), alpha=\(submitButton.alpha)")
    }
    
    @objc func submitGuess() {
        guard isMyTurn else {
            let alert = UIAlertController(title: "Not Your Turn", 
                                        message: "Please wait for your turn", 
                                        preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        guard let guess = guessTextField.text, !guess.isEmpty else { return }
        
        // 🚀 OPTIMISTIC UPDATE: Update UI immediately for smooth experience
        performOptimisticGuessUpdate(guess: guess)
        
        // Then sync with server in background
        submitGuessToServer(guess: guess)
    }
    
    // MARK: - Optimistic Updates for Ultra-Smooth UX
    
    private func performOptimisticGuessUpdate(guess: String) {
        print("⚡ Optimistic update: guess '\(guess)'")
        
        // 1. Immediate visual feedback
        submitButton.isEnabled = false
        submitButton.setTitle("🚀 SENDING...", for: .normal)
        
        // 2. Visual feedback with subtle animation
        UIView.animate(withDuration: 0.2, animations: {
            self.guessTextField.alpha = 0.8
            self.submitButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.guessTextField.alpha = 1.0
                self.submitButton.transform = CGAffineTransform.identity
            }
        }
        
        // 3. Immediate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // 4. Clear guess field immediately
        guessTextField.text = ""
        
        // 5. Optimistically switch turn (will be corrected by server if wrong)
        let oldTurn = currentTurn
        let oldIsMyTurn = isMyTurn
        
        // Find opponent to switch turn to
        // This is optimistic - server will correct if needed
        isMyTurn = false
        updateKeypadButtonsState() // Disable keypad immediately
        
        // Store optimistic state for potential rollback
        pendingOptimisticUpdates["guess"] = [
            "guess": guess,
            "oldTurn": oldTurn,
            "oldIsMyTurn": oldIsMyTurn,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // 6. Show optimistic feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.submitButton.setTitle("✨ PROCESSING...", for: .normal)
        }
    }
    
    private func submitGuessToServer(guess: String) {
        let url = URL(string: "\(baseURL)/game/guess-local")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0 // Normal timeout for server submission
        
        let body = [
            "roomId": roomId,
            "playerId": playerId,
            "guess": guess
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ Error creating request: \(error)")
            rollbackOptimisticUpdate(type: "guess")
            return
        }
        
        print("🎯 Submitting guess to server: \(guess)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Server submission failed: \(error)")
                    self.rollbackOptimisticUpdate(type: "guess")
                    self.showNetworkError("Failed to submit guess. Please try again.")
                    return
                }
                
                guard let data = data else {
                    print("❌ No server response")
                    self.rollbackOptimisticUpdate(type: "guess")
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let success = json["success"] as? Bool, success {
                            self.handleSuccessfulGuessSubmission(json: json, guess: guess)
                        } else {
                            print("❌ Server rejected guess: \(json)")
                            self.rollbackOptimisticUpdate(type: "guess")
                            let errorMessage = json["error"] as? String ?? "Server error"
                            self.showNetworkError(errorMessage)
                        }
                    }
                } catch {
                    print("❌ JSON parsing error: \(error)")
                    self.rollbackOptimisticUpdate(type: "guess")
                }
            }
        }.resume()
    }
    
    private func handleSuccessfulGuessSubmission(json: [String: Any], guess: String) {
        print("✅ Server confirmed guess: \(guess)")
        
        // Clear optimistic update (it was successful)
        pendingOptimisticUpdates.removeValue(forKey: "guess")
        
        // Process actual server result
        if let result = json["result"] as? [String: Any],
           let bulls = result["bulls"] as? Int,
           let cows = result["cows"] as? Int {
            
            // Show actual result
            submitButton.setTitle("✅ \(bulls)B \(cows)C", for: .normal)
            
            // Update turn with server data
            if let newCurrentTurn = json["currentTurn"] as? String {
                currentTurn = newCurrentTurn
                isMyTurn = (currentTurn == playerId)
            }
            
            // Check for win condition
            if let isCorrect = result["isCorrect"] as? Int, isCorrect == 1 {
                submitButton.setTitle("🏆 YOU WON!", for: .normal)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.showGameOverAlert(won: true)
                }
            } else if bulls == digits {
                submitButton.setTitle("🏆 YOU WON!", for: .normal)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.showGameOverAlert(won: true)
                }
            } else {
                // Update UI for next turn
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.resetSubmitButtonState()
                    self.updateTurnUI()
                }
            }
            
            // Trigger immediate background sync for latest data
            backgroundSync()
            
        } else {
            print("❌ Invalid result format from server")
            rollbackOptimisticUpdate(type: "guess")
        }
    }
    
    private func rollbackOptimisticUpdate(type: String) {
        print("🔄 Rolling back optimistic update: \(type)")
        
        if let guessUpdate = pendingOptimisticUpdates[type] as? [String: Any] {
            // Restore previous state
            if let oldTurn = guessUpdate["oldTurn"] as? String,
               let oldIsMyTurn = guessUpdate["oldIsMyTurn"] as? Bool {
                currentTurn = oldTurn
                isMyTurn = oldIsMyTurn
            }
            
            // Update UI to reflect rollback
            resetSubmitButtonState()
            updateTurnUI()
            updateKeypadButtonsState()
            
            // Clear the pending update
            pendingOptimisticUpdates.removeValue(forKey: type)
        }
    }
    
    private func resetSubmitButtonState() {
        submitButton.setTitle("🚀 LAUNCH ATTACK", for: .normal)
        submitButton.isEnabled = isMyTurn && (guessTextField.text?.count == digits)
        updateKeypadButtonsState()
    }
    
    private func showNetworkError(_ message: String) {
        let alert = UIAlertController(title: "Network Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc func leaveGame() {
        let alert = UIAlertController(title: "Leave Game?", 
                                    message: "Are you sure you want to leave this game?", 
                                    preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Leave", style: .destructive) { _ in
            self.leaveGameRequest()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}