//
//  Sakai.swift
//  Sakai
//
//  Created by Alastair Hendricks on 2018/05/20.
//

import Foundation
import Result
import Moya
import WebKit

public typealias NetworkServiceResponse<T: Decodable> = (Result<T, SakaiError>) -> Void

final public class SakaiAPIClient: NSObject {

    public let announcements: AnnouncementService = AnnouncementService()
    public let session: SessionService = SessionService()
    public let site: SiteService = SiteService()
    public let content: ContentService = ContentService()
    public let chat: ChatService = ChatService()
    public let calendar: CalendarService = CalendarService()
    public let assignement: AssignmentService = AssignmentService()
    public let webContent: WebContentService = WebContentService()
    public let syllabus: SyllabusService = SyllabusService()
    public let gradebook: GradebookService = GradebookService()
    public internal(set) var loggedInUserSession: SakaiSession?

    internal var username: String? = nil
    internal var password: String? = nil
    public internal(set) var baseURL: URL? = nil
    public var processPool: WKProcessPool = WKProcessPool()
    internal var errorReportingEngine: SakaiErrorReportingEngine?

    public class var shared: SakaiAPIClient {
        struct Static {
            static let instance: SakaiAPIClient = SakaiAPIClient()
        }
        return Static.instance
    }

    public override init() {
        super.init()
    }

    public func start(configuration: SakaiConfiguration, username: String, password: String) {
        self.baseURL = configuration.baseURL
        self.username = username
        self.password = password
    }

    public func teardown() {
        self.baseURL = nil
        self.username = nil
        self.password = nil
        self.loggedInUserSession = nil
    }

    public func ensureUserIsAuthorized() -> Bool {
        guard let session: SakaiSession = loggedInUserSession else {
            return false
        }
        let currentTimestamp = Time.getCurrentTimestamp()
        let lastRefreshed = session.lastAccessedTime/1000

        let timeElapsed = currentTimestamp-lastRefreshed

        if timeElapsed >= 60  {
            return false
        }

        return true
    }
}

