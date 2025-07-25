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
        // 🔒 SAFETY CHECKS: Ensure UI elements exist
        guard let guessTextField = self.guessTextField,
              let submitButton = self.submitButton else {
            print("⚠️ UI elements not ready for guess submission")
            return
        }
        
        guard isMyTurn else {
            print("⚠️ Not player's turn")
            let alert = UIAlertController(title: "Not Your Turn", 
                                        message: "Please wait for your turn", 
                                        preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        guard let guess = guessTextField.text, !guess.isEmpty else {
            print("⚠️ Empty guess text")
            return
        }
        
        // 🔒 VALIDATE GUESS FORMAT
        guard guess.count == digits else {
            print("⚠️ Invalid guess length: \(guess.count) != \(digits)")
            return
        }
        
        print("🎯 Submitting valid guess: '\(guess)'")
        
        // 🚀 OPTIMISTIC UPDATE: Update UI immediately for smooth experience
        performOptimisticGuessUpdate(guess: guess)
        
        // Then sync with server in background
        submitGuessToServer(guess: guess)
    }
    
    // MARK: - Optimistic Updates for Ultra-Smooth UX
    
    private func performOptimisticGuessUpdate(guess: String) {
        print("⚡ Optimistic update: guess '\(guess)'")
        
        // 🔒 SAFETY: Ensure UI elements exist before updating
        guard let submitButton = self.submitButton,
              let guessTextField = self.guessTextField else {
            print("⚠️ UI elements not available for optimistic update")
            return
        }
        
        // 1. Immediate visual feedback
        submitButton.isEnabled = false
        submitButton.setTitle("🚀 SENDING...", for: .normal)
        
        // 2. Visual feedback with subtle animation
        UIView.animate(withDuration: 0.2, animations: {
            guessTextField.alpha = 0.8
            submitButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                guessTextField.alpha = 1.0
                submitButton.transform = CGAffineTransform.identity
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
        // 🎯 DIRECT POST: Fast & Silent submission
        prioritizeRequest(type: "guess") { [weak self] in
            self?.performDirectGuessSubmission(guess: guess)
        }
    }
    
    private func performDirectGuessSubmission(guess: String) {
        let url = URL(string: "\(baseURL)/game/guess-local")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = 5.0 // Fast timeout for instant feel
        
        let body = [
            "roomId": roomId,
            "playerId": playerId,
            "guess": guess
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ Request creation failed: \(error)")
            rollbackOptimisticUpdate(type: "guess")
            return
        }
        
        print("🚀 Direct POST: guess '\(guess)' -> \(baseURL)/game/guess-local")
        
        // Use optimized session for better performance
        sharedURLSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("🎯 Silent error: \(error.localizedDescription)")
                    self.handleGuessSubmissionSilently(success: false, guess: guess)
                    return
                }
                
                guard let data = data else {
                    print("🎯 No response data")
                    self.handleGuessSubmissionSilently(success: false, guess: guess)
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let success = json["success"] as? Bool, success {
                            self.handleSuccessfulGuessSubmission(json: json, guess: guess)
                        } else {
                            print("🎯 Server rejected: \(json["error"] as? String ?? "Unknown")")
                            self.handleGuessSubmissionSilently(success: false, guess: guess)
                        }
                    } else {
                        print("🎯 Invalid JSON format")
                        self.handleGuessSubmissionSilently(success: false, guess: guess)
                    }
                } catch {
                    print("🎯 JSON parse error: \(error.localizedDescription)")
                    self.handleGuessSubmissionSilently(success: false, guess: guess)
                }
            }
        }.resume()
    }
    
    private func handleGuessSubmissionSilently(success: Bool, guess: String) {
        if success {
            print("✅ Guess submitted successfully")
            // Clear optimistic update
            pendingOptimisticUpdates.removeValue(forKey: "guess")
        } else {
            print("🎯 Guess submission failed silently, will retry in background")
            
            // Rollback optimistic update silently
            rollbackOptimisticUpdate(type: "guess")
            
            // Schedule silent retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.retryGuessSubmission(guess: guess)
            }
        }
        
        // Always trigger background sync for latest state
        backgroundSync()
    }
    
    private func retryGuessSubmission(guess: String) {
        print("🔄 Silent retry: guess '\(guess)'")
        performDirectGuessSubmission(guess: guess)
    }
    
    private func handleSuccessfulGuessSubmission(json: [String: Any], guess: String) {
        print("✅ Server confirmed guess: \(guess)")
        
        // Clear optimistic update (it was successful)
        pendingOptimisticUpdates.removeValue(forKey: "guess")
        
        // 🔒 SAFETY: Basic result processing with extensive safety checks
        guard let result = json["result"] as? [String: Any] else {
            print("⚠️ No result object in response")
            backgroundSync()
            return
        }
        
        let bulls = result["bulls"] as? Int ?? 0
        let cows = result["cows"] as? Int ?? 0
        let isCorrect = result["isCorrect"] as? Int ?? 0
        
        // Show result on button
        DispatchQueue.main.async {
            self.submitButton.setTitle("✅ \(bulls)B \(cows)C", for: .normal)
        }
        
        // 🎯 SIMPLIFIED WIN HANDLING
        if isCorrect == 1 {
            DispatchQueue.main.async {
                self.submitButton.setTitle("🏆 CORRECT!", for: .normal)
            }
            
            // Check for practice mode safely
            if let gameState = json["gameState"] as? String,
               gameState == "WINNER_ANNOUNCED" {
                
                if let winner = json["winner"] as? [String: Any],
                   let winnerId = winner["playerId"] as? String,
                   winnerId != playerId {
                    // Practice mode completion
                    print("🎯 Practice mode completion detected")
                    DispatchQueue.main.async {
                        self.submitButton.setTitle("🎯 SECRET FOUND!", for: .normal)
                    }
                    handlePracticeCompletion(discoveredSecret: guess)
                    return
                }
            }
            
            print("🏆 Normal victory detected")
        }
        
        // 🔒 SAFE TURN UPDATE
        if let newCurrentTurn = json["currentTurn"] as? String {
            currentTurn = newCurrentTurn
            isMyTurn = (currentTurn == playerId)
            print("🔄 Turn updated to: \(newCurrentTurn)")
        }
        
        // Reset button after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.resetSubmitButtonState()
            self.updateTurnUI()
        }
        
        // Always trigger background sync for latest data
        backgroundSync()
    }
    
    private func handlePracticeCompletion(discoveredSecret: String) {
        print("🎯 Practice completion started for secret: \(discoveredSecret)")
        
        // Notify server about practice completion
        let url = URL(string: "\(baseURL)/game/practice-complete-local")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "roomId": roomId,
            "playerId": playerId,
            "discoveredSecret": discoveredSecret
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ Error creating practice completion request: \(error)")
            return
        }
        
        sharedURLSession.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Practice completion failed: \(error)")
                    return
                }
                
                print("🎯 Practice completion confirmed")
                self?.showPracticeCompletionUI()
            }
        }.resume()
    }
    
    private func showPracticeCompletionUI() {
        // 🔒 SAFETY CHECK: Ensure we're on main thread and view exists
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.showPracticeCompletionUI()
            }
            return
        }
        
        guard let view = self.view else {
            print("⚠️ View not available for practice completion UI")
            return
        }
        
        // Update practice panel to show "PLAY AGAIN" button
        if let practicePanel = view.subviews.first(where: { $0.accessibilityIdentifier == "practice-panel" }) {
            print("🎯 Found practice panel, updating UI")
            
            // Find and show play again button
            for subview in practicePanel.subviews {
                if let button = subview as? UIButton {
                    button.isHidden = false
                    print("🎯 Enabled play again button")
                    break
                }
            }
            
            // Update subtitle if found
            let labels = practicePanel.subviews.compactMap { $0 as? UILabel }
            if labels.count >= 2 {
                labels[1].text = "🎉 Secret discovered! Ready for rematch?"
                print("🎯 Updated subtitle text")
            }
        } else {
            print("⚠️ Practice panel not found - creating simple completion message")
            // Create simple completion message instead of trying to update non-existent panel
            showSimpleCompletionMessage()
        }
        
        // Disable further guessing
        guessTextField.isEnabled = false
        submitButton.isEnabled = false
        updateKeypadButtonsState()
    }
    
    private func showSimpleCompletionMessage() {
        // Simple fallback UI for practice completion
        let completionLabel = UILabel()
        completionLabel.text = "🎉 Secret discovered!"
        completionLabel.textAlignment = .center
        completionLabel.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
        completionLabel.textColor = .white
        completionLabel.font = UIFont.boldSystemFont(ofSize: 16)
        completionLabel.layer.cornerRadius = 8
        completionLabel.clipsToBounds = true
        completionLabel.accessibilityIdentifier = "simple-completion"
        
        view.addSubview(completionLabel)
        completionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            completionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            completionLabel.topAnchor.constraint(equalTo: guessTextField.bottomAnchor, constant: 20),
            completionLabel.widthAnchor.constraint(equalToConstant: 200),
            completionLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            completionLabel.removeFromSuperview()
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