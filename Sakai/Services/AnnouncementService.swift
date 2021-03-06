//
//  AnnouncementService.swift
//  Sakai
//
//  Created by Alastair Hendricks on 2018/05/20.
//

import Foundation

public class AnnouncementService {
    public func getAnnouncement(withID id: String, completion: @escaping NetworkServiceResponse<SakaiAnnouncement>) {
        SakaiAPIClient.shared.session.prepAuthedRoute { (sessionResult) in
            if let authError = sessionResult.error {
                completion(.failure(authError))
                return
            }

            sakaiProvider.request(.announcement(id)) { result in
                switch result {
                case .success(let response):
                    do {
                        let announcement: SakaiAnnouncement = try JSONDecoder().decode(SakaiAnnouncement.self, from: response.data)
                        self.getAnnouncementSiteTitles(announcements: [announcement], completion: { (titleResults) in
                            switch titleResults {
                            case .success(let finalAnnouncements):
                                guard let finalAnnouncement: SakaiAnnouncement = finalAnnouncements.first else {
                                    completion(.failure(SakaiError.init(kind: .unknown, localizedDescription: nil)))
                                    return
                                }

                                completion(.success(finalAnnouncement))
                                return
                            case .failure(let titleErrors):
                                completion(.failure(titleErrors))
                                return
                            }
                        })
                    } catch {
                        let error = SakaiError.parse(result: result)
                        completion(.failure(error))
                        return
                    }

                case .failure:
                    let sakaiError = SakaiError.parse(result: result)
                    completion(.failure(sakaiError))
                    return
                }
            }
        }
    }

    public func getSiteAnnouncements(id: String, completion: @escaping NetworkServiceResponse<[SakaiAnnouncement]>) {
        SakaiAPIClient.shared.session.prepAuthedRoute { (sessionResult) in
            if let authError = sessionResult.error {
                completion(.failure(authError))
                return
            }

            sakaiProvider.request(.announcementsSite(id)) { result in
                let result = ResponseHelper.handle([SakaiAnnouncement].self, result: result, atKeyPath: "announcement_collection")

                guard let announcements: [SakaiAnnouncement] = result.value else {
                    completion(result)
                    return
                }

                let strippedAnnouncements: [SakaiAnnouncement] = self.stripAnnouncements(announcements: announcements)

                completion(.success(strippedAnnouncements))
                return
            }
        }
    }

    public func getRecentAnnouncements(sitleTitles: Bool = true, completion: @escaping NetworkServiceResponse<[SakaiAnnouncement]>) {
        SakaiAPIClient.shared.session.prepAuthedRoute { (sessionResult) in
            if let authError = sessionResult.error {
                completion(.failure(authError))
                return
            }

            sakaiProvider.request(.recentAnnouncements) { (result) in
                switch result {
                case .success(let response):
                    do {
                        let announcementCollection: SakaiAnnouncementCollection = try JSONDecoder().decode(SakaiAnnouncementCollection.self, from: response.data)
                        let announcements: [SakaiAnnouncement] = announcementCollection.collection.sorted(by: { $0.createdOn > $1.createdOn })
                        if sitleTitles {
                            self.getAnnouncementSiteTitles(announcements: announcements, completion: { (titleResults) in
                                switch titleResults {
                                case .success(let finalAnnouncements):
                                    let finalAnnouncements = self.stripAnnouncements(announcements: finalAnnouncements)
                                    completion(.success(finalAnnouncements))
                                    return
                                case .failure:
                                    let sakaiError = SakaiError.parse(result: result)
                                    completion(.failure(sakaiError))
                                    return
                                }
                            })
                        } else {
                            let finalAnnouncements = self.stripAnnouncements(announcements: announcements)
                            completion(.success(finalAnnouncements))
                            return
                        }
                    } catch {

                    }
                case .failure:
                    let sakaiError = SakaiError.parse(result: result)
                    completion(.failure(sakaiError))
                    return
                }
            }
        }
    }

    func stripAnnouncements(announcements: [SakaiAnnouncement]) -> [SakaiAnnouncement] {
        let finalAnnouncements: [SakaiAnnouncement] = announcements.map({
            var announcement: SakaiAnnouncement = $0
            announcement.strippedBody = announcement.body?.stripHTML()
            announcement.title = announcement.title?.trimmingCharacters(in: [" "])
            return announcement
        })
        return finalAnnouncements
    }

    public func getSiteTitle(announcement: SakaiAnnouncement, completion: @escaping NetworkServiceResponse<SakaiAnnouncement>) {
        var resultAnnouncement = announcement
        sakaiProvider.request(.site(announcement.siteId), completion: { (result) in
            do {
                let response = try result.get()
                let site = try response.map(SakaiSite.self)
                resultAnnouncement.displaySiteTitle = site.title
                completion(.success(resultAnnouncement))
            } catch {
                let fail = SakaiError.parse(result: result)
                completion(.failure(fail))
                return
            }
        })
    }

    internal func getAnnouncementSiteTitles(announcements: [SakaiAnnouncement], completion: @escaping NetworkServiceResponse<[SakaiAnnouncement]>) {
        var newAnnouncements: [SakaiAnnouncement] = []
        for announcement in announcements {
            self.getSiteTitle(announcement: announcement) { result in
                if let announcementToAdd = result.value {
                    newAnnouncements.append(announcementToAdd)
                }
                if announcements.count == newAnnouncements.count {
                    completion(.success(newAnnouncements))
                    return
                }
            }
        }
    }
}
