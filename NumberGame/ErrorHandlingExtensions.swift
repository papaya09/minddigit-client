import UIKit
import AudioToolbox

// MARK: - Error Handling UI Extensions

extension UIViewController {
    
    // Show error with retry option
    func showError(_ message: String, canRetry: Bool = false, retryAction: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "⚠️ Connection Issue",
                message: message,
                preferredStyle: .alert
            )
            
            // Add OK button
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            // Add retry button if requested
            if canRetry, let retryAction = retryAction {
                alert.addAction(UIAlertAction(title: "🔄 Retry", style: .default) { _ in
                    retryAction()
                })
            }
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            self.present(alert, animated: true)
        }
    }
    
    // Show network status indicator
    func showNetworkStatus(_ isOnline: Bool) {
        DispatchQueue.main.async {
            let statusView = NetworkStatusView(isOnline: isOnline)
            statusView.show(in: self.view)
        }
    }
    
    // Show loading with message
    func showLoading(_ message: String = "Loading...") -> UIView {
        let loadingView = LoadingView(message: message)
        view.addSubview(loadingView)
        loadingView.fillSuperview()
        return loadingView
    }
    
    // Hide loading view
    func hideLoading(_ loadingView: UIView) {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.3) {
                loadingView.alpha = 0
            } completion: { _ in
                loadingView.removeFromSuperview()
            }
        }
    }
}

// MARK: - Network Status View

class NetworkStatusView: UIView {
    private let statusLabel = UILabel()
    private let isOnline: Bool
    private var hideTimer: Timer?
    
    init(isOnline: Bool) {
        self.isOnline = isOnline
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = isOnline ? .systemGreen : .systemRed
        layer.cornerRadius = 8
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.3
        
        statusLabel.text = isOnline ? "🌐 Back Online" : "📵 Offline"
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 16, weight: .medium)
        statusLabel.textAlignment = .center
        
        addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16)
        ])
    }
    
    func show(in parentView: UIView) {
        parentView.addSubview(self)
        
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: parentView.centerXAnchor),
            topAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.topAnchor, constant: 16),
            heightAnchor.constraint(equalToConstant: 44),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])
        
        // Animate in
        alpha = 0
        transform = CGAffineTransform(translationX: 0, y: -50)
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.alpha = 1
            self.transform = .identity
        }
        
        // Auto hide after 3 seconds if online
        if isOnline {
            hideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                self.hide()
            }
        }
    }
    
    private func hide() {
        UIView.animate(withDuration: 0.3) {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: -30)
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
}

// MARK: - Loading View

class LoadingView: UIView {
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
    private let containerView = UIView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let messageLabel = UILabel()
    
    init(message: String) {
        super.init(frame: .zero)
        setupUI(message: message)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI(message: String) {
        // Blur background
        addSubview(blurView)
        blurView.fillSuperview()
        
        // Container
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 8
        containerView.layer.shadowOpacity = 0.2
        
        addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 200),
            containerView.heightAnchor.constraint(equalToConstant: 120)
        ])
        
        // Activity indicator
        activityIndicator.startAnimating()
        containerView.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24)
        ])
        
        // Message label
        messageLabel.text = message
        messageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        messageLabel.textColor = .label
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 2
        
        containerView.addSubview(messageLabel)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -16)
        ])
        
        // Animate in
        alpha = 0
        containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
            self.alpha = 1
            self.containerView.transform = .identity
        }
    }
}

// MARK: - UIView Extensions

extension UIView {
    func fillSuperview() {
        guard let superview = superview else { return }
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: superview.topAnchor),
            leadingAnchor.constraint(equalTo: superview.leadingAnchor),
            trailingAnchor.constraint(equalTo: superview.trailingAnchor),
            bottomAnchor.constraint(equalTo: superview.bottomAnchor)
        ])
    }
    
    func addBounceAnimation() {
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = .identity
            }
        }
    }
}

// MARK: - Game State UI Helpers

extension GameStateManager {
    func getConnectionStatusText() -> String {
        if isOffline {
            return "📵 Offline Mode"
        } else if let lastSync = lastServerSync {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "🌐 Synced at \(formatter.string(from: lastSync))"
        } else {
            return "🌐 Online"
        }
    }
    
    func getConnectionStatusColor() -> UIColor {
        return isOffline ? .systemRed : .systemGreen
    }
}