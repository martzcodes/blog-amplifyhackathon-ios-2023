import UIKit
import Amplify
import AWSCognitoAuthPlugin

class Backend {
    enum AuthStatus {
        case signedIn
        case signedOut
        case sessionExpired
    }
    
    static let shared = Backend()
    static func initialize() -> Backend {
        return .shared
    }
    
    func updateUserData(withSignInStatus status : Bool) async {
        await MainActor.run {
            let userData : UserData = .shared
            userData.isSignedIn = status
        }
    }
    
    private init() {
      // initialize amplify
      do {
          try Amplify.add(plugin: AWSCognitoAuthPlugin())
          try Amplify.configure()
          print("Initialized Amplify");
      } catch {
        print("Could not initialize Amplify: \(error)")
      }
    }
    
    public func getInitialAuthStatus() async throws -> AuthStatus {
        // let's check if user is signedIn or not
        let session = try await Amplify.Auth.fetchAuthSession()
        return session.isSignedIn ? AuthStatus.signedIn : AuthStatus.signedOut
    }
    
    public func listenAuthUpdate() async -> AsyncStream<AuthStatus> {
            
        return AsyncStream { continuation in
            
            continuation.onTermination = { @Sendable status in
                       print("[BACKEND] streaming auth status terminated with status : \(status)")
            }
            
            // listen to auth events.
            // see https://github.com/aws-amplify/amplify-ios/blob/master/Amplify/Categories/Auth/Models/AuthEventName.swift
            let _  = Amplify.Hub.listen(to: .auth) { payload in
                
                print(payload.eventName)
                switch payload.eventName {
                    
                case HubPayload.EventName.Auth.signedIn:
                    print("==HUB== User signed In, update UI")
                    continuation.yield(AuthStatus.signedIn)
                case HubPayload.EventName.Auth.signedOut:
                    print("==HUB== User signed Out, update UI")
                    continuation.yield(AuthStatus.signedOut)
                case "Auth.federationToIdentityPoolCleared":
                    print("==HUB== User unfederated, update UI")
                    continuation.yield(AuthStatus.signedOut)
                case HubPayload.EventName.Auth.sessionExpired:
                    print("==HUB== Session expired, show sign in aui")
                    continuation.yield(AuthStatus.sessionExpired)
                default:
                    print("==HUB== \(payload)")
                    break
                }
            }
        }
    }
    
    func clearFederation() async {
        guard
            let plugin = try? Amplify.Auth.getPlugin(for: "awsCognitoAuthPlugin") as? AWSCognitoAuthPlugin
        else { return }
        
        Task {
            do {
                let result = try await plugin.clearFederationToIdentityPool()
                print("Successfully un-federated user to identity pool with result:", result)
            } catch {
                print("Failed to un-federate to identity pool with error:", error)
            }
        }
    }
    
    // signout
    public func signOut() async {
        print("backend... calling signout")
        let _ = await clearFederation()
    }
}
