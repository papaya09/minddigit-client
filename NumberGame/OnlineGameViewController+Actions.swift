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
            return
        }
        
        print("🎯 Submitting guess: \(guess)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Network error submitting guess: \(error)")
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
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
                            
                            // Clear the guess field
                            self.guessTextField.text = ""
                            self.guessTextChanged() // Update button state
                            
                            // Check for win condition immediately
                            if let isCorrect = result["isCorrect"] as? Int, isCorrect == 1 {
                                print("🎉 WIN DETECTED! You guessed correctly!")
                                // Delay to allow history update
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    self.showGameOverAlert(won: true)
                                }
                            } else if bulls == self.digits {
                                print("🎉 WIN DETECTED by bulls count!")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    self.showGameOverAlert(won: true)
                                }
                            }
                            
                            // Update history immediately
                            self.updateHistory()
                        }
                    }
                } else {
                    print("❌ Invalid guess response format")
                }
            } catch {
                print("❌ Error parsing guess response: \(error)")
            }
        }.resume()
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