import UIKit

// MARK: - Actions & Game Logic
extension OnlineGameViewController {
    
    @objc func keypadNumberTapped(_ sender: UIButton) {
        print("🔢 Keypad tapped: \(sender.tag), isMyTurn: \(isMyTurn), gameState: \(gameState)")
        
        // Allow input in continue guessing mode OR when it's my turn
        if gameState == "CONTINUE_GUESSING" {
            print("✅ Continue guessing mode - allowing input")
        } else if !isMyTurn {
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
        // Allow clear in continue guessing mode OR when it's my turn
        guard isMyTurn || gameState == "CONTINUE_GUESSING" else {
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
        
        // In continue guessing mode, always allow submission when valid length
        if gameState == "CONTINUE_GUESSING" {
            submitButton.isEnabled = isValidLength
            submitButton.alpha = isValidLength ? 1.0 : 0.5
        } else {
            // Normal mode: Enable submit button only if valid length AND it's my turn
            submitButton.isEnabled = isValidLength && isMyTurn
            submitButton.alpha = (isValidLength && isMyTurn) ? 1.0 : 0.5
        }
        
        print("🔤 Guess text changed: '\(currentGuess)' (\(currentGuess.count)/\(digits)) - Valid: \(isValidLength), MyTurn: \(isMyTurn), Mode: \(gameState)")
        print("🎯 Submit button updated: enabled=\(submitButton.isEnabled), alpha=\(submitButton.alpha)")
    }
    
    @objc func submitGuess() {
        print("🚀 Submit guess triggered - gameState: \(gameState), isMyTurn: \(isMyTurn)")
        print("🚀 Current guess text: '\(guessTextField.text ?? "")'")
        
        // In continue guessing mode, skip turn checking
        if gameState != "CONTINUE_GUESSING" {
            guard isMyTurn else {
                print("❌ Submit blocked: Not your turn in normal mode")
                let alert = UIAlertController(title: "Not Your Turn", 
                                            message: "Please wait for your turn", 
                                            preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            }
        }
        
        guard let guess = guessTextField.text, !guess.isEmpty else { 
            print("❌ Submit blocked: Empty guess")
            return 
        }
        
        print("✅ Proceeding with guess: '\(guess)'")
        
        if gameState == "CONTINUE_GUESSING" {
            print("🎯 Handling continue guessing mode")
            // Handle continue guessing mode specially
            handleContinueGuessing(guess: guess)
        } else {
            print("🎮 Handling normal game mode")
            // 🚀 OPTIMISTIC UPDATE: Update UI immediately for smooth experience
            performOptimisticGuessUpdate(guess: guess)
            
            // Then sync with server in background
            submitGuessToServer(guess: guess)
        }
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
                    }
                } catch {
                    print("🎯 Parse error: \(error)")
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
        
        // Process actual server result
        if let result = json["result"] as? [String: Any],
           let bulls = result["bulls"] as? Int,
           let cows = result["cows"] as? Int {
            
            // Show actual result
            submitButton.setTitle("✅ \(bulls)B \(cows)C", for: .normal)
            
            // Update turn with server data
            if let newCurrentTurn = json["currentTurn"] as? String {
                currentTurn = newCurrentTurn
                // Don't update isMyTurn in continue guessing mode
                if gameState != "CONTINUE_GUESSING" {
                    isMyTurn = (currentTurn == playerId)
                } else {
                    print("🎯 PROTECTED: Not updating isMyTurn in continue guessing mode (handleSuccessfulGuessSubmission)")
                }
            }
            
            // Check for win condition or continue guessing success
            if let isCorrect = result["isCorrect"] as? Int, isCorrect == 1 {
                if gameState == "CONTINUE_GUESSING" {
                    // Successfully decoded enemy secret in continue mode
                    submitButton.setTitle("🎯 SECRET DECODED!", for: .normal)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.showContinueGuessingSuccessModal()
                    }
                } else {
                    // Normal game win - I won!
                    submitButton.setTitle("🏆 YOU WON!", for: .normal)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.showGameOverAlert(won: true)
                    }
                }
            } else if bulls == digits {
                if gameState == "CONTINUE_GUESSING" {
                    // Successfully decoded enemy secret in continue mode
                    submitButton.setTitle("🎯 SECRET DECODED!", for: .normal)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.showContinueGuessingSuccessModal()
                    }
                } else {
                    // Normal game win - I won!
                    submitButton.setTitle("🏆 YOU WON!", for: .normal)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.showGameOverAlert(won: true)
                    }
                }
            } else {
                // Continue guessing or normal turn
                if gameState == "CONTINUE_GUESSING" {
                    // Update UI for next guess in continue mode
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.resetContinueGuessingButtonState()
                        // Don't call updateTurnUI() - resetContinueGuessingButtonState() handles it
                    }
                } else {
                    // Update UI for next turn in normal game
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.resetSubmitButtonState()
                        self.updateTurnUI()
                    }
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
    
    // MARK: - Continue Guessing Mode
    
    private func handleContinueGuessing(guess: String) {
        print("🎯 Continue guessing mode: analyzing guess '\(guess)' locally")
        
        // Immediate visual feedback
        submitButton.isEnabled = false
        submitButton.setTitle("🔍 ANALYZING...", for: .normal)
        
        // Visual feedback with animation
        UIView.animate(withDuration: 0.2, animations: {
            self.guessTextField.alpha = 0.8
            self.submitButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.guessTextField.alpha = 1.0
                self.submitButton.transform = CGAffineTransform.identity
            }
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Clear guess field immediately
        guessTextField.text = ""
        
        // Analyze locally (no server call needed)
        performLocalAnalysis(guess: guess)
    }
    
    private func performLocalAnalysis(guess: String) {
        print("🔍 Performing local analysis: '\(guess)' vs '\(opponentSecret)'")
        
        // Validate inputs
        guard !opponentSecret.isEmpty else {
            print("❌ No opponent secret available for analysis")
            handleContinueGuessResult(success: false, guess: guess, bulls: 0, cows: 0)
            return
        }
        
        guard guess.count == opponentSecret.count else {
            print("❌ Guess length (\(guess.count)) doesn't match secret length (\(opponentSecret.count))")
            handleContinueGuessResult(success: false, guess: guess, bulls: 0, cows: 0)
            return
        }
        
        // Calculate bulls and cows
        let result = analyzeGuessLocally(guess: guess, secret: opponentSecret)
        
        // Simulate a brief delay for realistic feel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.handleContinueGuessResult(success: true, guess: guess, bulls: result.bulls, cows: result.cows)
        }
    }
    
    private func analyzeGuessLocally(guess: String, secret: String) -> (bulls: Int, cows: Int) {
        print("🧮 Local analysis: guess='\(guess)', secret='\(secret)'")
        
        var bulls = 0
        var cows = 0
        
        let guessArray = Array(guess)
        let secretArray = Array(secret)
        
        // Count bulls (correct position)
        for i in 0..<guessArray.count {
            if guessArray[i] == secretArray[i] {
                bulls += 1
            }
        }
        
        // Count total matches for cows calculation
        var secretCount: [Character: Int] = [:]
        var guessCount: [Character: Int] = [:]
        
        for char in secretArray {
            secretCount[char, default: 0] += 1
        }
        
        for char in guessArray {
            guessCount[char, default: 0] += 1
        }
        
        var totalMatches = 0
        for (char, count) in guessCount {
            totalMatches += min(count, secretCount[char, default: 0])
        }
        
        cows = totalMatches - bulls // cows = total matches - bulls
        
        print("📊 Analysis result: \(bulls)B \(cows)C")
        return (bulls, cows)
    }
    
    private func submitContinueGuessToServer(guess: String) {
        let url = URL(string: "\(baseURL)/game/guess-continue")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = 5.0
        
        let body = [
            "roomId": roomId,
            "playerId": playerId,
            "guess": guess,
            "mode": "continue_guessing",
            "targetSecret": opponentSecret // Secret to guess against
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ Continue guess request creation failed: \(error)")
            resetContinueGuessingButtonState()
            return
        }
        
        print("🎯 Sending continue guess: '\(guess)' -> \(baseURL)/game/guess-continue")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("🎯 Continue guess error: \(error.localizedDescription)")
                    self.handleContinueGuessResult(success: false, guess: guess, bulls: 0, cows: 0)
                    return
                }
                
                guard let data = data else {
                    print("🎯 No response data for continue guess")
                    self.handleContinueGuessResult(success: false, guess: guess, bulls: 0, cows: 0)
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let success = json["success"] as? Bool, success,
                           let result = json["result"] as? [String: Any],
                           let bulls = result["bulls"] as? Int,
                           let cows = result["cows"] as? Int {
                            self.handleContinueGuessResult(success: true, guess: guess, bulls: bulls, cows: cows)
                        } else {
                            print("🎯 Continue guess server error: \(json["error"] as? String ?? "Unknown")")
                            self.handleContinueGuessResult(success: false, guess: guess, bulls: 0, cows: 0)
                        }
                    }
                } catch {
                    print("🎯 Continue guess parse error: \(error)")
                    self.handleContinueGuessResult(success: false, guess: guess, bulls: 0, cows: 0)
                }
            }
        }.resume()
    }
    
    private func handleContinueGuessResult(success: Bool, guess: String, bulls: Int, cows: Int) {
        if !success {
            // Handle error case
            submitButton.setTitle("❌ TRY AGAIN", for: .normal)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.resetContinueGuessingButtonState()
            }
            return
        }
        
        // Show result
        submitButton.setTitle("📊 \(bulls)B \(cows)C", for: .normal)
        
        // Check if we decoded the secret
        if bulls == digits {
            // Successfully decoded enemy secret!
            submitButton.setTitle("🎯 SECRET DECODED!", for: .normal)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showContinueGuessingSuccessModal()
            }
        } else {
            // Continue analyzing - reset button after showing result
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.resetContinueGuessingButtonState()
            }
        }
        
        // Add the guess to local history for reference
        addContinueGuessToLocalHistory(guess: guess, bulls: bulls, cows: cows)
    }
    
    private func addContinueGuessToLocalHistory(guess: String, bulls: Int, cows: Int) {
        // Create a local history entry for continue guessing
        let entry: [String: Any] = [
            "playerName": "🕵️ Intelligence Analysis",
            "guess": guess,
            "bulls": bulls,
            "cows": cows,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "isContinueGuess": true
        ]
        
        // Add to history container if available
        guard let historyContainer = self.historyContainer else { return }
        
        let historyItemView = createHistoryItemView(
            playerName: "🕵️ Intelligence Analysis",
            guess: guess,
            bulls: bulls,
            cows: cows
        )
        
        // Special styling for continue guessing entries
        historyItemView.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.3)
        historyItemView.layer.borderColor = UIColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 0.9).cgColor
        
        // Smooth fade-in animation
        historyItemView.alpha = 0.0
        historyItemView.transform = CGAffineTransform(translationX: 0, y: 20)
        historyContainer.addArrangedSubview(historyItemView)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            historyItemView.alpha = 1.0
            historyItemView.transform = CGAffineTransform.identity
        }
        
        // Auto-scroll to show new entries
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let scrollView = historyContainer.superview as? UIScrollView {
                let bottomOffset = CGPoint(x: 0, y: max(0, scrollView.contentSize.height - scrollView.bounds.height))
                scrollView.setContentOffset(bottomOffset, animated: true)
            }
        }
    }
}