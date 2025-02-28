import DatabaseClient
import Either
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import HttpPipeline
import HttpPipelineTestSupport
import Overture
import Prelude
import PushMiddleware
import ServerRouter
import ServerRoutes
import SharedModels
import SiteMiddleware
import SnapshotTesting
import XCTest

@testable import SnsClient

class PushMiddlewareTests: XCTestCase {
  func testRegisterToken() throws {
    var createPlatformRequest: SnsClient.CreatePlatformRequest?
    var insertPushTokenRequest: DatabaseClient.InsertPushTokenRequest?

    let environment = update(Environment.unimplemented) {
      $0.database.fetchPlayerByAccessToken = { _ in pure(.blob) }
      $0.database.insertPushToken = { request in
        insertPushTokenRequest = request
        return pure(())
      }
      $0.snsClient.createPlatformEndpoint = { request in
        createPlatformRequest = request
        return pure(.init(response: .init(result: .init(endpointArn: "arn:deadbeef"))))
      }
    }

    var request = URLRequest(
      url: URL(string: "/api/push-tokens?accessToken=deadbeef-dead-beef-dead-beefdeadbeef")!)
    request.httpMethod = "POST"
    request.httpBody = Data(#"{"token":"deadbeef"}"#.utf8)

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    XCTAssertEqual(
      createPlatformRequest,
      .init(
        apnsToken: "deadbeef",
        platformApplicationArn: "arn:aws:sns:us-east-1:1234567890:app/APNS/deadbeef"
      )
    )
    XCTAssertEqual(
      insertPushTokenRequest,
      .init(
        arn: "arn:deadbeef",
        authorizationStatus: .provisional,
        build: 0,
        player: .blob,
        token: "deadbeef"
      )
    )

    _assertInlineSnapshot(matching: result, as: .conn, with: """
      POST /api/push-tokens?accessToken=deadbeef-dead-beef-dead-beefdeadbeef

      {"token":"deadbeef"}

      200 OK
      Content-Length: 4
      Content-Type: application/json
      Referrer-Policy: strict-origin-when-cross-origin
      X-Content-Type-Options: nosniff
      X-Download-Options: noopen
      X-Frame-Options: SAMEORIGIN
      X-Permitted-Cross-Domain-Policies: none
      X-XSS-Protection: 1; mode=block

      {

      }
      """
    )
  }

  func testRegisterToken_WithBuild() throws {
    var createPlatformRequest: SnsClient.CreatePlatformRequest?
    var insertPushTokenRequest: DatabaseClient.InsertPushTokenRequest?

    let environment = update(Environment.unimplemented) {
      $0.database.fetchPlayerByAccessToken = { _ in pure(.blob) }
      $0.database.insertPushToken = { request in
        insertPushTokenRequest = request
        return pure(())
      }
      $0.snsClient.createPlatformEndpoint = { request in
        createPlatformRequest = request
        return pure(.init(response: .init(result: .init(endpointArn: "arn:deadbeef"))))
      }
    }

    var request = URLRequest(
      url: URL(string: "/api/push-tokens?accessToken=deadbeef-dead-beef-dead-beefdeadbeef")!)
    request.httpMethod = "POST"
    request.httpBody = Data(#"{"build":42,"token":"deadbeef"}"#.utf8)

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    XCTAssertEqual(
      createPlatformRequest,
      .init(
        apnsToken: "deadbeef",
        platformApplicationArn: "arn:aws:sns:us-east-1:1234567890:app/APNS/deadbeef"
      )
    )
    XCTAssertEqual(
      insertPushTokenRequest,
      .init(
        arn: "arn:deadbeef",
        authorizationStatus: .provisional,
        build: 42,
        player: .blob,
        token: "deadbeef"
      )
    )

    _assertInlineSnapshot(matching: result, as: .conn, with: """
      POST /api/push-tokens?accessToken=deadbeef-dead-beef-dead-beefdeadbeef

      {"build":42,"token":"deadbeef"}

      200 OK
      Content-Length: 4
      Content-Type: application/json
      Referrer-Policy: strict-origin-when-cross-origin
      X-Content-Type-Options: nosniff
      X-Download-Options: noopen
      X-Frame-Options: SAMEORIGIN
      X-Permitted-Cross-Domain-Policies: none
      X-XSS-Protection: 1; mode=block

      {

      }
      """
    )
  }

  func testRegisterToken_WithBuildAndAuthorizationStatus() throws {
    var createPlatformRequest: SnsClient.CreatePlatformRequest?
    var insertPushTokenRequest: DatabaseClient.InsertPushTokenRequest?

    let environment = update(Environment.unimplemented) {
      $0.database.fetchPlayerByAccessToken = { _ in pure(.blob) }
      $0.database.insertPushToken = { request in
        insertPushTokenRequest = request
        return pure(())
      }
      $0.snsClient.createPlatformEndpoint = { request in
        createPlatformRequest = request
        return pure(.init(response: .init(result: .init(endpointArn: "arn:deadbeef"))))
      }
    }

    var request = URLRequest(
      url: URL(string: "/api/push-tokens?accessToken=deadbeef-dead-beef-dead-beefdeadbeef")!)
    request.httpMethod = "POST"
    request.httpBody = Data(#"{"authorizationStatus":2,"build":42,"token":"deadbeef"}"#.utf8)

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    XCTAssertEqual(
      createPlatformRequest,
      .init(
        apnsToken: "deadbeef",
        platformApplicationArn: "arn:aws:sns:us-east-1:1234567890:app/APNS/deadbeef"
      )
    )
    XCTAssertEqual(
      insertPushTokenRequest,
      .init(
        arn: "arn:deadbeef",
        authorizationStatus: .authorized,
        build: 42,
        player: .blob,
        token: "deadbeef"
      )
    )

    _assertInlineSnapshot(matching: result, as: .conn, with: """
      POST /api/push-tokens?accessToken=deadbeef-dead-beef-dead-beefdeadbeef

      {"authorizationStatus":2,"build":42,"token":"deadbeef"}

      200 OK
      Content-Length: 4
      Content-Type: application/json
      Referrer-Policy: strict-origin-when-cross-origin
      X-Content-Type-Options: nosniff
      X-Download-Options: noopen
      X-Frame-Options: SAMEORIGIN
      X-Permitted-Cross-Domain-Policies: none
      X-XSS-Protection: 1; mode=block

      {

      }
      """
    )
  }

  func testRegisterSandboxToken() throws {
    var createPlatformRequest: SnsClient.CreatePlatformRequest?
    var insertPushTokenRequest: DatabaseClient.InsertPushTokenRequest?

    let environment = update(Environment.unimplemented) {
      $0.database.fetchPlayerByAccessToken = { _ in pure(.blob) }
      $0.database.insertPushToken = { request in
        insertPushTokenRequest = request
        return pure(())
      }
      $0.snsClient.createPlatformEndpoint = { request in
        createPlatformRequest = request
        return pure(.init(response: .init(result: .init(endpointArn: "arn:deadbeef"))))
      }
    }

    var request = URLRequest(
      url: URL(string: "/api/push-tokens?accessToken=deadbeef-dead-beef-dead-beefdeadbeef")!)
    request.addValue("true", forHTTPHeaderField: "X-Debug")
    request.httpMethod = "POST"
    request.httpBody = Data(#"{"token":"deadbeef"}"#.utf8)

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    XCTAssertEqual(
      createPlatformRequest,
      .init(
        apnsToken: "deadbeef",
        platformApplicationArn: "arn:aws:sns:us-east-1:1234567890:app/APNS_SANDBOX/deadbeef"
      )
    )
    XCTAssertEqual(
      insertPushTokenRequest,
      .init(
        arn: "arn:deadbeef",
        authorizationStatus: .provisional,
        build: 0,
        player: .blob,
        token: "deadbeef"
      )
    )

    _assertInlineSnapshot(matching: result, as: .conn, with: """
      POST /api/push-tokens?accessToken=deadbeef-dead-beef-dead-beefdeadbeef
      X-Debug: true

      {"token":"deadbeef"}

      200 OK
      Content-Length: 4
      Content-Type: application/json
      Referrer-Policy: strict-origin-when-cross-origin
      X-Content-Type-Options: nosniff
      X-Download-Options: noopen
      X-Frame-Options: SAMEORIGIN
      X-Permitted-Cross-Domain-Policies: none
      X-XSS-Protection: 1; mode=block

      {

      }
      """
    )
  }

  func testUpdateSetting() throws {
    var playerId: Player.Id?
    var notificationType: PushNotificationContent.CodingKeys?
    var sendNotifications: Bool?

    let environment = update(Environment.unimplemented) {
      $0.database.fetchPlayerByAccessToken = { _ in pure(.blob) }
      $0.database.updatePushSetting = {
        (playerId, notificationType, sendNotifications) = ($0, $1, $2)
        return pure(())
      }
    }

    var request = URLRequest(
      url: URL(string: "/api/push-settings?accessToken=deadbeef-dead-beef-dead-beefdeadbeef")!)
    request.httpMethod = "POST"
    request.httpBody = Data(
      #"""
      {"notificationType":"dailyChallengeEndsSoon","sendNotifications":false}
      """#.utf8)

    let middleware = siteMiddleware(environment: environment)
    let result = middleware(connection(from: request)).perform()

    XCTAssertEqual(playerId, Player.blob.id)
    XCTAssertEqual(notificationType, .dailyChallengeEndsSoon)
    XCTAssertEqual(sendNotifications, false)

    _assertInlineSnapshot(matching: result, as: .conn, with: """
      POST /api/push-settings?accessToken=deadbeef-dead-beef-dead-beefdeadbeef

      {"notificationType":"dailyChallengeEndsSoon","sendNotifications":false}

      200 OK
      Content-Length: 4
      Content-Type: application/json
      Referrer-Policy: strict-origin-when-cross-origin
      X-Content-Type-Options: nosniff
      X-Download-Options: noopen
      X-Frame-Options: SAMEORIGIN
      X-Permitted-Cross-Domain-Policies: none
      X-XSS-Protection: 1; mode=block

      {

      }
      """
    )
  }

}
