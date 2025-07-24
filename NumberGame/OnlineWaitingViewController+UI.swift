import UIKit

// MARK: - UI Helper Methods
extension OnlineWaitingViewController {
    
    func setupRefreshButton() {
        let refreshButton = UIButton(type: .system)
        refreshButton.setTitle("🔄 Refresh", for: .normal)
        refreshButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.7)
        refreshButton.setTitleColor(.white, for: .normal)
        refreshButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        refreshButton.layer.cornerRadius = 15
        refreshButton.layer.borderWidth = 1
        refreshButton.layer.borderColor = UIColor.white.cgColor
        refreshButton.addTarget(self, action: #selector(refreshButtonTapped), for: .touchUpInside)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        
        let debugButton = UIButton(type: .system)
        debugButton.setTitle("🐛 Debug", for: .normal)
        debugButton.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.7)
        debugButton.setTitleColor(.white, for: .normal)
        debugButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        debugButton.layer.cornerRadius = 15
        debugButton.layer.borderWidth = 1
        debugButton.layer.borderColor = UIColor.white.cgColor
        debugButton.addTarget(self, action: #selector(debugButtonTapped), for: .touchUpInside)
        debugButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(refreshButton)
        view.addSubview(debugButton)
        
        NSLayoutConstraint.activate([
            refreshButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            refreshButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            refreshButton.widthAnchor.constraint(equalToConstant: 80),
            refreshButton.heightAnchor.constraint(equalToConstant: 30),
            
            debugButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            debugButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            debugButton.widthAnchor.constraint(equalToConstant: 80),
            debugButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    @objc func debugButtonTapped() {
        print("🐛 DEBUG INFO:")
        print("   Player Name: \(playerName)")
        print("   Room ID: \(roomId)")
        print("   Player ID: \(playerId)")
        print("   Position: \(position)")
        print("   Game State: \(gameState)")
        print("   Base URL: \(baseURL)")
        
        // Test simple GET request
        testConnection()
        
        let alert = UIAlertController(title: "🐛 Debug Info", 
                                    message: "Check Xcode console for logs\n\nRoom: \(roomId)\nPlayer: \(playerId)\nState: \(gameState)", 
                                    preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    func testConnection() {
        print("🧪 Testing connection to: \(baseURL)/health")
        
        guard let url = URL(string: "\(baseURL)/health") else {
            print("❌ Invalid health URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Health check failed: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Health check status: \(httpResponse.statusCode)")
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("📨 Health response: \(responseString)")
            }
        }.resume()
    }
    
    @objc func refreshButtonTapped() {
        // Stop auto polling when user manually refreshes
        stopPolling()
        
        // Manual refresh
        checkRoomStatus()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Show brief loading state
        if let button = view.subviews.first(where: { $0 is UIButton && ($0 as! UIButton).currentTitle?.contains("🔄") == true }) as? UIButton {
            button.setTitle("⏳", for: .normal)
            button.isEnabled = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                button.setTitle("🔄 Refresh", for: .normal)
                button.isEnabled = true
            }
        }
    }
    
    func setupSmartPolling() {
        // Only poll if we have valid room and player IDs
        guard !roomId.isEmpty, !playerId.isEmpty else {
            print("⚠️ Cannot start polling: Missing roomId or playerId")
            stopPolling()
            return
        }
        
        print("🎯 Setting up smart polling for state: \(gameState)")
        
        // Only poll when necessary
        switch gameState {
        case "WAITING":
            // Poll every 3 seconds when waiting for players
            startSmartPolling(interval: 3.0)
        case "DIGIT_SELECTION", "SECRET_SETTING":
            // Poll every 2 seconds during setup phases
            startSmartPolling(interval: 2.0)
        case "PLAYING":
            // Stop polling once game starts (use manual refresh)
            stopPolling()
        default:
            stopPolling()
        }
    }
    
    private func startSmartPolling(interval: TimeInterval) {
        stopPolling()
        
        statusTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkRoomStatus()
        }
    }
    
    func showConnectionStatus(_ isConnected: Bool) {
        DispatchQueue.main.async {
            if isConnected {
                self.statusLabel.textColor = UIColor.systemGreen
                self.statusLabel.text = "🟢 Connected"
            } else {
                self.statusLabel.textColor = UIColor.systemRed
                self.statusLabel.text = "🔴 Connection Lost"
            }
        }
    }
    
    func animatePlayerJoin() {
        // Animate when second player joins
        UIView.animate(withDuration: 0.3, animations: {
            self.player2Label.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            self.player2Label.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
        }) { _ in
            UIView.animate(withDuration: 0.3) {
                self.player2Label.transform = .identity
            }
        }
        
        // Success haptic feedback
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)
    }
    
    func showQuickStatus(_ message: String, duration: TimeInterval = 2.0) {
        let statusView = UIView()
        statusView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        statusView.layer.cornerRadius = 20
        statusView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        statusView.addSubview(label)
        view.addSubview(statusView)
        
        NSLayoutConstraint.activate([
            statusView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            statusView.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            statusView.heightAnchor.constraint(equalToConstant: 40),
            
            label.centerXAnchor.constraint(equalTo: statusView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: statusView.leadingAnchor, constant: 15),
            label.trailingAnchor.constraint(lessThanOrEqualTo: statusView.trailingAnchor, constant: -15)
        ])
        
        // Animate in
        statusView.alpha = 0
        statusView.transform = CGAffineTransform(translationX: 0, y: -20)
        
        UIView.animate(withDuration: 0.3, animations: {
            statusView.alpha = 1
            statusView.transform = .identity
        }) { _ in
            // Auto hide after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                UIView.animate(withDuration: 0.3, animations: {
                    statusView.alpha = 0
                    statusView.transform = CGAffineTransform(translationX: 0, y: -20)
                }) { _ in
                    statusView.removeFromSuperview()
                }
            }
        }
    }
}