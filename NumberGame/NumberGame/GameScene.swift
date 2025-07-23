import SpriteKit

class GameScene: SKScene {
    
    // This class is now minimal - main functionality moved to UIKit controllers
    // (MainMenuViewController and GameplayViewController)
    
    private var titleLabel: SKLabelNode!
    
    override func didMove(to view: SKView) {
        // Simple placeholder scene - the actual game uses UIKit now
        setupPlaceholder()
    }
    
    private func setupPlaceholder() {
        backgroundColor = .systemBlue
        
        titleLabel = SKLabelNode(text: "Loading MindDigits...")
        titleLabel.fontSize = 32
        titleLabel.fontColor = .white
        titleLabel.fontName = "HelveticaNeue-Light"
        titleLabel.position = CGPoint(x: size.width/2, y: size.height/2)
        addChild(titleLabel)
        
        // The app will immediately switch to UIKit-based views
        // This scene is just a brief loading placeholder
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // No touch handling needed - UIKit handles everything now
    }
}