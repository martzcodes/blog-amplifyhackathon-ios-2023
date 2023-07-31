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
    @ObservedObject private var userData: UserData = .shared
    
    @State var showCreateNote = false

    @State var name : String        = "New Note"
    @State var description : String = "This is a new note"


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
            guard let tokenString = String(data: identityToken, encoding: .utf8) else {
                return
            }
            Backend.shared.federateToIdentityPools(with: tokenString)
            self.userData.isSignedIn = true;
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
                    .navigationBarItems(leading: SignOutButton(),
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
                    List {
                        ForEach(userData.notes) { note in
                            ListRow(note: note)
                        }
                    }
                }
            }
        }.task {
            // get the initial authentication status. This call will change app state according to result
            try? await Backend.shared.getInitialAuthStatus()
            
            try? await Backend.shared.queryNotes()
            
            // start a long polling to listen to auth updates
            await Backend.shared.listenAuthUpdate()
        }
    }
}

struct SignOutButton : View {
    var body: some View {
        Button(action: { Task { await Backend.shared.signOut() } }) {
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
    @State var image : UIImage? // replace the previous declaration of image
    @State var showCaptureImageView = false
    var body: some View {
        Form {

            Section(header: Text("TEXT")) {
                TextField("Name", text: $name)
                TextField("Name", text: $description)
            }

            Section(header: Text("PICTURE")) {
                VStack {
                    Button(action: {
                        self.showCaptureImageView.toggle()
                    }) {
                        Text("Choose photo")
                    }.sheet(isPresented: $showCaptureImageView) {
                        CaptureImageView(isShown: self.$showCaptureImageView, image: self.$image)
                    }
                    if (image != nil ) {
                        HStack {
                            Spacer()
                            Image(uiImage: image!)
                                .resizable()
                                .frame(width: 250, height: 200)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                                .shadow(radius: 10)
                            Spacer()
                        }
                    }
                }
            }

            Section {
                Button(action: {
                    self.isPresented = false

                    let note = Note(id : UUID().uuidString,
                                    name: self.$name.wrappedValue,
                                    description: self.$description.wrappedValue)

                    if let i = self.image  {
                        note.imageName = UUID().uuidString
                        note.image = Image(uiImage: i)

                        // asynchronously store the image (and assume it will work)
                        Backend.shared.storeImage(name: note.imageName!, image: (i.pngData())!)
                    }

                    // asynchronously store the note (and assume it will succeed)
                    Backend.shared.createNote(note: note)

                    // add the new note in our userdata, this will refresh UI
                    withAnimation { self.userData.notes.append(note) }
                }) {
                    Text("Create this note")
                }
            }
        }
    }
}
