//
//  ViewModel.swift
//  AmplifyPushUp
//
//  Created by Matt Martz on 7/30/23.
//

import Foundation
import SwiftUI

enum AppState {
    case signedOut
    case loading
    case signedIn
    case error(Error)
}

// singleton object to store user data
@MainActor
class ViewModel : ObservableObject {
    
    @Published var state : AppState = .signedOut
    
    // MARK: Authentication
    public func getInitialAuthStatus() async throws {
        
            
        let status = try await Backend.shared.getInitialAuthStatus()
        print("INITIAL AUTH STATUS is \(status)")
        switch status {
            case .signedIn: self.state = .loading
            case .signedOut, .sessionExpired:  self.state = .signedOut
        }
    }
    
    public func listenAuthUpdate() async {
            for try await status in await Backend.shared.listenAuthUpdate() {
                print("AUTH STATUS LOOP yielded \(status)")
                switch status {
                case .signedIn:
                    self.state = .loading
                case .signedOut, .sessionExpired:
                    self.state = .signedOut
                }
            }
            print("==== EXITED AUTH STATUS LOOP =====")
    }
    
    public func signIn() {
        Task {
            self.state = .signedIn
        }
    }
    
    // asynchronously sign out
    // change of status will be picked up by `listenAuthUpdate`
    // that will trigger the UI update
    public func signOut() {
        Task {
            await Backend.shared.signOut()
        }
    }
}

extension ViewModel {
    static var mock : ViewModel = mockedData(isSignedIn: true)
    static var signedOutMock : ViewModel = mockedData(isSignedIn: false)

    private static func mockedData(isSignedIn: Bool) -> ViewModel {
        let model = ViewModel()
        
        if isSignedIn {
            //
        } else {
            model.state = .signedOut
        }

        return model
    }
}
