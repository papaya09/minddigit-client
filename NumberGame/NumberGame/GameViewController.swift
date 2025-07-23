//
//  GameViewController.swift
//  NumberGame
//
//  Created by Admin on 23/7/2568 BE.
//

import UIKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup modern UI-based main menu
        setupMainMenu()
    }
    
    private func setupMainMenu() {
        let mainMenuVC = MainMenuViewController()
        mainMenuVC.modalPresentationStyle = .fullScreen
        
        // Present main menu immediately
        DispatchQueue.main.async {
            self.present(mainMenuVC, animated: false)
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
