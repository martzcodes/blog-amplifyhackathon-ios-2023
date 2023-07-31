import Amplify
import AWSCognitoAuthPlugin
import AuthenticationServices
import SwiftUI

struct ListRow: View {
    @ObservedObject var note : Note
var body: some View {

        return HStack(alignment: .center, spacing: 5.0) {

            // if there is an image, display it on the left
if (note.image != nil) {
                note.image!
                .resizable()
                .frame(width: 50, height: 50)
            }

            // the right part is a vertical stack with the title and description
VStack(alignment: .leading, spacing: 5.0) {
                Text(note.name)
                .bold()

                if ((note.description) != nil) {
                    Text(note.description!)
                }
            }
        }
    }
}

// this is the main view of our app,
// it is made of a Table with one line per Note
struct ContentView: View {
    @EnvironmentObject public var model: ViewModel
    @ObservedObject private var userData: UserData = .shared
    
    @State var showCreateNote = false

    @State var name : String        = "New Note"
    @State var description : String = "This is a new note"
    @State var image : String       = "image"
    
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
        ZStack {
            if (userData.isSignedIn) {
                NavigationView {
                    List {
                        ForEach(userData.notes) { note in
                            ListRow(note: note)
                        }.onDelete { indices in
                            indices.forEach {
                                // removing from user data will refresh UI
                                let note = self.userData.notes.remove(at: $0)

                                // asynchronously remove from database
                                Backend.shared.deleteNote(note: note)
                            }
                        }
                    }
                    .navigationBarTitle(Text("Notes"))
                    .navigationBarItems(leading: SignOutButton(model : self.model),
                                        trailing: Button(action: {
                        self.showCreateNote.toggle()
                    }) {
                        Image(systemName: "plus")
                    })
                }.sheet(isPresented: $showCreateNote) {
                    AddNoteView(isPresented: self.$showCreateNote, userData: self.userData)
                }
            } else {
                VStack {
                    SignInWithAppleButton(
                        onRequest: configureRequest,
                        onCompletion: handleResult
                    )
                    .frame(maxWidth: 300, maxHeight: 45)
                }
            }
        }.task {
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

struct AddNoteView: View {
    @Binding var isPresented: Bool
    var userData: UserData

    @State var name : String        = "New Note"
    @State var description : String = "This is a new note"
    @State var image : String       = "image"
    var body: some View {
        Form {

            Section(header: Text("TEXT")) {
                TextField("Name", text: $name)
                TextField("Name", text: $description)
            }

            Section(header: Text("PICTURE")) {
                TextField("Name", text: $image)
            }

            Section {
                Button(action: {
                    self.isPresented = false
                    let noteData = NoteData(id : UUID().uuidString,
                                            name: self.$name.wrappedValue,
                                            description: self.$description.wrappedValue)
                    let note = Note(from: noteData)

                    // asynchronously store the note (and assume it will succeed)
                    Backend.shared.createNote(note: note)

                    // add the new note in our userdata, this will refresh UI
                    self.userData.notes.append(note)
                }) {
                    Text("Create this note")
                }
            }
        }
    }
}
