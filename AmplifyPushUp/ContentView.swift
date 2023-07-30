import Amplify
import AWSCognitoAuthPlugin
import AuthenticationServices
import SwiftUI

// this is the main view of our app,
// it is made of a Table with one line per Note
struct ContentView: View {
    @EnvironmentObject public var model: ViewModel
    @ObservedObject private var userData: UserData = .shared
    
    func federateToIdentityPools(with token: Data) {
        guard
            let tokenString = String(data: token, encoding: .utf8),
            let plugin = try? Amplify.Auth.getPlugin(for: "awsCognitoAuthPlugin") as? AWSCognitoAuthPlugin
        else { return }
        
        Task {
            do {
                self.userData.userToken = tokenString;
                let result = try await plugin.federateToIdentityPool(
                    withProviderToken: tokenString,
                    for: .apple
                )
                print("Successfully federated user to identity pool with result:", result)
            } catch {
                print("Failed to federate to identity pool with error:", error)
            }
        }
    }

    func configureRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.email]
    }

    func handleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken else {
                return
            }
            self.federateToIdentityPools(with: identityToken)
            self.model.signIn()
        case .failure(let error):
            print(error)
        }
    }
    
    var body: some View {
        VStack {
            SignInWithAppleButton(
                onRequest: configureRequest,
                onCompletion: handleResult
            )
            .frame(maxWidth: 300, maxHeight: 45)
            SignOutButton(model : self.model)
        }
        .task {
                    // get the initial authentication status. This call will change app state according to result
                    try? await self.model.getInitialAuthStatus()
                    
                    // start a long polling to listen to auth updates
                    await self.model.listenAuthUpdate()
                }
        
    }
}

struct SignOutButton : View {
    var model : ViewModel
    var body: some View {
        Button(action: { self.model.signOut() }) {
                Text("Sign Out")
        }
    }
}

// this is use to preview the UI in Xcode
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {

        prepareTestData()

        return ContentView()
    }
}
