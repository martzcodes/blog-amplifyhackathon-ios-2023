// swiftlint:disable all
import Amplify
import Foundation

extension NoteData {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case name
    case description
    case image
    case createdAt
    case updatedAt
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let noteData = NoteData.keys
    
    model.authRules = [
      rule(allow: .public, provider: .iam, operations: [.read]),
      rule(allow: .private, provider: .iam, operations: [.read, .create, .update, .delete])
    ]
    
    model.pluralName = "NoteData"
    
    model.attributes(
      .primaryKey(fields: [noteData.id])
    )
    
    model.fields(
      .field(noteData.id, is: .required, ofType: .string),
      .field(noteData.name, is: .required, ofType: .string),
      .field(noteData.description, is: .optional, ofType: .string),
      .field(noteData.image, is: .optional, ofType: .string),
      .field(noteData.createdAt, is: .optional, isReadOnly: true, ofType: .dateTime),
      .field(noteData.updatedAt, is: .optional, isReadOnly: true, ofType: .dateTime)
    )
    }
}

extension NoteData: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}