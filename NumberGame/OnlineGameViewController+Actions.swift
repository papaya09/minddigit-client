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
        
        // Immediate visual feedback - disable controls
        submitButton.isEnabled = false
        submitButton.setTitle("🚀 LAUNCHING...", for: .normal)
        updateKeypadButtonsState() // Disable keypad
        
        // Visual feedback - pulsing effect
        UIView.animate(withDuration: 0.3, delay: 0, options: [.repeat, .autoreverse], animations: {
            self.guessTextField.alpha = 0.7
        }) { _ in
            self.guessTextField.alpha = 1.0
        }
        
        let url = URL(string: "\(baseURL)/game/guess-local")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "roomId": roomId,
            "playerId": playerId,
            "guess": guess
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ Error creating request: \(error)")
            resetSubmitButtonState()
            return
        }
        
        print("🎯 Submitting guess: \(guess)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Stop pulsing animation
                self.guessTextField.layer.removeAllAnimations()
                self.guessTextField.alpha = 1.0
            }
            
            if let error = error {
                print("❌ Network error submitting guess: \(error)")
                DispatchQueue.main.async {
                    self.resetSubmitButtonState()
                    self.showNetworkError("Failed to submit guess. Please try again.")
                }
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                DispatchQueue.main.async {
                    self.resetSubmitButtonState()
                    self.showNetworkError("No response from server.")
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📨 Guess response: \(json)")
                    
                    if let success = json["success"] as? Bool, success,
                       let result = json["result"] as? [String: Any],
                       let bulls = result["bulls"] as? Int,
                       let cows = result["cows"] as? Int {
                        
                        DispatchQueue.main.async {
                            print("🎯 \(guess): \(bulls)B \(cows)C")
                            
                            // Immediate feedback - show result briefly
                            self.submitButton.setTitle("✅ \(bulls)B \(cows)C", for: .normal)
                            
                            // Clear the guess field
                            self.guessTextField.text = ""
                            
                            // Update turn immediately (opponent's turn)
                            if let newCurrentTurn = json["currentTurn"] as? String {
                                self.currentTurn = newCurrentTurn
                                self.isMyTurn = (self.currentTurn == self.playerId)
                                print("🔄 Turn switched to: \(newCurrentTurn), isMyTurn: \(self.isMyTurn)")
                            }
                            
                            // Check for win condition immediately
                            if let isCorrect = result["isCorrect"] as? Int, isCorrect == 1 {
                                print("🎉 WIN DETECTED! You guessed correctly!")
                                self.submitButton.setTitle("🏆 YOU WON!", for: .normal)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    self.showGameOverAlert(won: true)
                                }
                            } else if bulls == self.digits {
                                print("🎉 WIN DETECTED by bulls count!")
                                self.submitButton.setTitle("🏆 YOU WON!", for: .normal)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    self.showGameOverAlert(won: true)
                                }
                            } else {
                                // Not a win, update UI for opponent's turn
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    self.updateTurnUI()
                                }
                            }
                            
                            // Start aggressive polling for immediate updates
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                self.startAggressivePolling()
                            }
                        }
                    } else {
                        print("❌ Server returned error: \(json)")
                        DispatchQueue.main.async {
                            self.resetSubmitButtonState()
                            let errorMessage = json["error"] as? String ?? "Unknown server error"
                            self.showNetworkError(errorMessage)
                        }
                    }
                } else {
                    print("❌ Invalid guess response format")
                    DispatchQueue.main.async {
                        self.resetSubmitButtonState()
                        self.showNetworkError("Invalid response from server.")
                    }
                }
            } catch {
                print("❌ Error parsing guess response: \(error)")
                DispatchQueue.main.async {
                    self.resetSubmitButtonState()
                    self.showNetworkError("Failed to parse server response.")
                }
            }
        }.resume()
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