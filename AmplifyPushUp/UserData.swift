import SwiftUI

// singleton object to store user data
class UserData : ObservableObject {
    private init() {}
    static let shared = UserData()

    @Published var isSignedIn : Bool = false
    @Published var userToken: String = ""
}
// this is a test data set to preview the UI in Xcode
@discardableResult
func prepareTestData() -> UserData {
    let userData = UserData.shared
    userData.isSignedIn = true

    return userData
}
