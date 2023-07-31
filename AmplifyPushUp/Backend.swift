import UIKit
import Amplify
import AWSCognitoAuthPlugin
import AWSAPIPlugin

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
    
    // change our internal state, this triggers an UI update on the main thread
    func updateUserData(withSignInStatus status : Bool) async {
        await MainActor.run {
            let userData : UserData = .shared
            userData.isSignedIn = status

            // when user is signed in, query the database, otherwise empty our model
    if status {
                self.queryNotes()
            } else {
                userData.notes = []
            }
        }
    }
    
    private init() {
      // initialize amplify
      do {
          try Amplify.add(plugin: AWSCognitoAuthPlugin())
          try Amplify.add(plugin: AWSAPIPlugin(modelRegistration: AmplifyModels()))
          try Amplify.configure()
          print("Initialized Amplify");
      } catch {
        print("Could not initialize Amplify: \(error)")
      }
        
        Task {
            do {
                let session = try await Amplify.Auth.fetchAuthSession()

                // let's update UserData and the UI
        await self.updateUserData(withSignInStatus: session.isSignedIn)
            } catch {
                print("Fetch auth session failed with error - \(error)")
            }
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
                case "Auth.federatedToIdentityPool":
                    print("==HUB== User federated, update UI")
                    continuation.yield(AuthStatus.signedIn)
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
    
    // MARK: API Access
    func queryNotes() {
            Task {
                do {
                    let result = try await Amplify.API.query(request: .list(NoteData.self))
                    
                    switch result {
                    case .success(let notesData):
                        print("Successfully retrieved list of Notes")

                        // convert an array of NoteData to an array of Note class instances
                        for n in notesData {
                            let note = Note.init(from: n)
                            await MainActor.run {
                                UserData.shared.notes.append(note)
                            }
                        }

                    case .failure(let error):
                        print("Can not retrieve result : error  \(error.errorDescription)")
                    }
                } catch {
                    print("Can not retrieve Notes : error \(error)")
                }
            }
        }

        func createNote(note: Note) {

            Task {
                do {
                    // use note.data to access the NoteData instance
                    let result = try await Amplify.API.mutate(request: .create(note.data))
                    switch result {
                        case .success(let data):
                            print("Successfully created note: \(data)")
                        case .failure(let error):
                            print("Got failed result with \(error.errorDescription)")
                        }
                } catch {
                    print("Got failed result with error \(error)")
                }
            }
        }

        func deleteNote(note: Note) {

            // use note.data to access the NoteData instance
    Task {
                do {
                    let result = try await Amplify.API.mutate(request: .delete(note.data))
                    switch result {
                    case .success(let data):
                        print("Successfully deleted note: \(data)")
                    case .failure(let error):
                        print("Got failed result with \(error.errorDescription)")
                    }
                } catch {
                    print("Got failed result with error \(error)")
                }
            }
        }
}
