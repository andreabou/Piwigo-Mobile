//
//  Upload.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/03/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
//  An NSManagedObject subclass for the Tag entity.

import CoreData

// MARK: - Core Data
/**
 Managed object subclass for the Upload entity.
 */

@objc
class Upload: NSManagedObject {

    // A unique identifier for removing duplicates. Constrain
    // the Piwigo Upload entity on this attribute in the data model editor.
    @NSManaged var localIdentifier: String
    
    // The other attributes of an upload.
    @NSManaged var requestDate: Date
    @NSManaged var category: Int64
    @NSManaged var privacyLevel: kPiwigoPrivacy
    @NSManaged var author: String?
    @NSManaged var title: String?
    @NSManaged var comment: String?
    @NSManaged var tags: [Tag]?

    // Singleton
    @objc static let sharedInstance: Upload = Upload()
    
    /**
     Updates an Upload instance with the values from a UploadProperties.
     */
    func update(with uploadProperties: UploadProperties) throws {
        
        // Local identifier of the image to upload
        localIdentifier = uploadProperties.localIdentifier
        
        // Category to upload the image to
        category = Int64(uploadProperties.category)
        
        // Date of upload request defaults to now
        requestDate = uploadProperties.requestDate

        // Photo author name defaults to name entered in Settings
        author = uploadProperties.author ?? Model.sharedInstance()?.defaultAuthor
        
        // Privacy level defaults to level selected in Settings
        guard let pLevel = uploadProperties.privacyLevel else {
            throw UploadError.missingData
        }
        privacyLevel = pLevel

        // Other properties have no predefined values
        title = uploadProperties.title ?? ""
        comment = uploadProperties.comment ?? ""
        tags = uploadProperties.tags ?? []
    }
}


// MARK: - Upload properties
/**
 A struct for managing upload requests
*/
struct UploadProperties
{
    let localIdentifier: String            // Unique PHAsset identifier
    let category: Int                      // 8
    let requestDate: Date                  // "2020-08-22 19:18:43"
    let author: String?                     // "Author"
    let privacyLevel: kPiwigoPrivacy?       // 0
    let title: String?                      // "Image title"
    let comment: String?                    // "A comment…"
    let tags: [Tag]?                        // Array of tags
}

extension UploadProperties {
    init(localIdentifier: String, category: Int) {
        self.init(localIdentifier: localIdentifier, category: category,
                  requestDate: Date.init(),
                  author: Model.sharedInstance()?.defaultAuthor ?? "",
                  privacyLevel: Model.sharedInstance()?.defaultPrivacyLevel ?? kPiwigoPrivacyEverybody,
                  title: "", comment: "", tags: [])
    }
}
