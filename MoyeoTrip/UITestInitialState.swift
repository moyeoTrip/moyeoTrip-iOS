//
//  UITestInitialState.swift
//  MoyeoTrip
//

import SwiftUI

struct UITestInitialState {
  var selectedTab: MoyeoTab
  var homePath = NavigationPath()
  var explorePath = NavigationPath()
  var meetingsPath = NavigationPath()
  var myPath = NavigationPath()
  var feedPostID: String?
  var feedStartsWriting = false
  var exploreStartsInMap = false

  init(arguments: [String]) {
    selectedTab = MoyeoTab.uiTestInitialTab(from: arguments) ?? .home

    guard let screen = UITestScreenRequest(arguments: arguments) else {
      return
    }

    _ =
      applyMyRoute(screen)
      || applyMeetingRoute(screen)
      || applyContentRoute(screen)
      || applyFeedRoute(screen)
      || applySupportRoute(screen)
      || applyExploreRoute(screen)
  }

  private mutating func applyMyRoute(_ screen: UITestScreenRequest) -> Bool {
    if screen.matches("profile") {
      selectedTab = .my
      myPath.append(MyRoute.profile)
      return true
    }
    if screen.matches("profile-edit", "profileedit", "edit-profile", "editprofile") {
      selectedTab = .my
      myPath.append(MyRoute.profileEdit)
      return true
    }
    if screen.matches("my-feed", "myfeed") {
      selectedTab = .my
      myPath.append(MyRoute.myFeed)
      return true
    }
    if screen.matches("settings") {
      selectedTab = .my
      myPath.append(MyRoute.settings)
      return true
    }
    if screen.matches("friend-dex", "frienddex") {
      selectedTab = .my
      myPath.append(MyRoute.friendDex)
      return true
    }
    if screen.matches("customer-center", "customercenter", "customer") {
      selectedTab = .my
      myPath.append(MyRoute.customerCenter)
      return true
    }
    return false
  }

  private mutating func applyMeetingRoute(_ screen: UITestScreenRequest) -> Bool {
    if screen.matches("special-messages", "specialmessages") {
      selectedTab = .meetings
      meetingsPath.append(MeetingsRoute.specialMessages)
      return true
    }
    if screen.matches("chat", "chat-room", "chatroom") {
      selectedTab = .meetings
      appendChat(screen.identifier)
      return true
    }
    return false
  }

  private mutating func applyContentRoute(_ screen: UITestScreenRequest) -> Bool {
    if screen.matches("course", "course-detail", "coursedetail") {
      selectedTab = .home
      appendCourse(screen.identifier)
      return true
    }
    if screen.matches("trip", "trip-detail", "recruitment", "recruitment-detail") {
      selectedTab = .home
      appendTrip(screen.identifier)
      return true
    }
    return false
  }

  private mutating func applyFeedRoute(_ screen: UITestScreenRequest) -> Bool {
    if screen.matches("feed-detail", "feeddetail", "feed-post", "feedpost") {
      selectedTab = .feed
      let postID = screen.identifier ?? "feed-01"
      feedPostID = MockData.feedPost(for: postID)?.id ?? postID
      return true
    }
    if screen.matches("feed-write", "feedwrite", "write-feed", "writefeed") {
      selectedTab = .feed
      feedStartsWriting = true
      return true
    }
    return false
  }

  // Direct-launch aliases intentionally cover design-spec filenames used by visual regression tests.
  // swiftlint:disable:next cyclomatic_complexity
  private mutating func applySupportRoute(_ screen: UITestScreenRequest) -> Bool {
    if screen.matches("auth", "login", "signup") {
      selectedTab = .home
      homePath.append(SupportRoute.authFlow)
      return true
    }
    if screen.matches("notifications", "notification") {
      selectedTab = .home
      homePath.append(SupportRoute.notifications)
      return true
    }
    if screen.matches("create", "create-recruitment", "createrecruitment") {
      selectedTab = .home
      let requestedCourseID =
        screen.identifier ?? MockData.courses.first?.id ?? "course-cheongsong-juwangsan"
      let courseID = MockData.course(for: requestedCourseID)?.id ?? requestedCourseID
      homePath.append(SupportRoute.createRecruitment(courseID))
      return true
    }
    if screen.matches("host", "host-manage", "hostmanage") {
      selectedTab = .home
      let requestedTripID =
        screen.identifier ?? MockData.trips.first?.id ?? "trip-cheongsong-juwangsan"
      let tripID = MockData.trip(for: requestedTripID)?.id ?? requestedTripID
      homePath.append(SupportRoute.hostManage(tripID))
      return true
    }
    if screen.matches("custom-course", "customcourse") {
      selectedTab = .home
      homePath.append(SupportRoute.customCourse)
      return true
    }
    if screen.matches("create-schedule", "createschedule") {
      selectedTab = .home
      homePath.append(SupportRoute.createSchedule)
      return true
    }
    if screen.matches("create-meet", "create-meeting", "createmeet") {
      selectedTab = .home
      homePath.append(SupportRoute.createMeeting)
      return true
    }
    if screen.matches("create-summary", "createsummary") {
      selectedTab = .home
      homePath.append(SupportRoute.createSummary)
      return true
    }
    if screen.matches("course-edit", "courseedit", "course-edit-custom") {
      selectedTab = .home
      homePath.append(SupportRoute.courseEdit(screen.identifier ?? MockData.trips[0].id, .editable))
      return true
    }
    if screen.matches("course-edit-linked", "courseeditlinked") {
      selectedTab = .home
      homePath.append(
        SupportRoute.courseEdit(screen.identifier ?? MockData.trips[0].id, .linkedLocked))
      return true
    }
    if screen.matches("course-edit-locked", "courseeditlocked") {
      selectedTab = .home
      homePath.append(
        SupportRoute.courseEdit(screen.identifier ?? MockData.trips[0].id, .tripConfirmed))
      return true
    }
    if screen.matches("notice-history", "noticehistory") {
      selectedTab = .home
      homePath.append(SupportRoute.noticeHistory(screen.identifier ?? MockData.chatThreads[0].id))
      return true
    }
    if screen.matches("trip-confirmed", "tripconfirmed") {
      selectedTab = .home
      let tripID = screen.identifier ?? "trip-cheongsong-juwangsan"
      homePath.append(SupportRoute.tripConfirmed(tripID))
      return true
    }
    return applyChangelogRoute(screen)
  }

  // swiftlint:disable:next cyclomatic_complexity
  private mutating func applyChangelogRoute(_ screen: UITestScreenRequest) -> Bool {
    if screen.matches("chat-menu", "chatmenu") {
      selectedTab = .home
      homePath.append(SupportRoute.chatMenu(screen.identifier ?? "chat-cheongsong-juwangsan"))
      return true
    }
    if screen.matches("chat-attach", "chatattach") {
      selectedTab = .home
      homePath.append(SupportRoute.chatAttach(screen.identifier ?? "chat-cheongsong-juwangsan"))
      return true
    }
    if screen.matches("friends") {
      selectedTab = .home
      homePath.append(SupportRoute.friends)
      return true
    }
    if screen.matches("trip-message", "tripmessage") {
      selectedTab = .home
      homePath.append(SupportRoute.tripMessage)
      return true
    }
    if screen.matches("report") {
      selectedTab = .home
      homePath.append(SupportRoute.report)
      return true
    }
    if screen.matches("blocked", "blocked-users", "blockedusers") {
      selectedTab = .home
      homePath.append(SupportRoute.blockedUsers)
      return true
    }
    if screen.matches("course-publish", "coursepublish") {
      selectedTab = .home
      homePath.append(SupportRoute.coursePublish)
      return true
    }
    if screen.matches("trip-day", "tripday") {
      selectedTab = .home
      homePath.append(SupportRoute.tripDay(screen.identifier ?? "chat-cheongsong-juwangsan"))
      return true
    }
    if screen.matches("notif-detail", "notification-detail", "notificationdetail") {
      selectedTab = .home
      homePath.append(SupportRoute.notificationDetail)
      return true
    }
    if screen.matches("account-delete", "accountdelete") {
      selectedTab = .home
      homePath.append(SupportRoute.accountDelete)
      return true
    }
    if screen.matches("system-maintenance", "systemmaintenance") {
      selectedTab = .home
      homePath.append(SupportRoute.systemMaintenance)
      return true
    }
    if screen.matches("system-error", "systemerror", "error-500") {
      selectedTab = .home
      homePath.append(SupportRoute.systemError)
      return true
    }
    if screen.matches("feed-comments", "feedcomments") {
      selectedTab = .home
      homePath.append(SupportRoute.feedComments(screen.identifier ?? "feed-03"))
      return true
    }
    return false
  }

  private mutating func applyExploreRoute(_ screen: UITestScreenRequest) -> Bool {
    if screen.matches("search") {
      selectedTab = .explore
      explorePath.append(SupportRoute.search)
      return true
    }
    if screen.matches("explore-map", "exploremap", "map") {
      selectedTab = .explore
      exploreStartsInMap = true
      return true
    }
    return false
  }

  private mutating func appendCourse(_ id: String?) {
    let courseID = id ?? "course-cheongsong-juwangsan"
    if let course = MockData.course(for: courseID) ?? MockData.courses.first {
      homePath.append(course)
    }
  }

  private mutating func appendTrip(_ id: String?) {
    let tripID = id ?? "trip-cheongsong-juwangsan"
    if let trip = MockData.trip(for: tripID) ?? MockData.trips.first {
      homePath.append(trip)
    }
  }

  private mutating func appendChat(_ id: String?) {
    let chatID = id ?? "chat-cheongsong-juwangsan"
    if let thread = MockData.chatThread(for: chatID) ?? MockData.chatThreads.first {
      meetingsPath.append(thread)
    }
  }
}

private struct UITestScreenRequest {
  let name: String
  let identifier: String?

  init?(arguments: [String]) {
    guard
      let rawValue =
        arguments
        .first(where: { $0.hasPrefix("UITEST_SCREEN=") })?
        .replacingOccurrences(of: "UITEST_SCREEN=", with: "")
    else {
      return nil
    }

    let parts = rawValue.split(separator: ":", maxSplits: 1).map(String.init)
    name = (parts.first ?? "")
      .replacingOccurrences(of: "_", with: "-")
      .lowercased()
    identifier = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil
  }

  func matches(_ values: String...) -> Bool {
    values.contains(name)
  }
}
