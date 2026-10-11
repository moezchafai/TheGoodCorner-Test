//
//  MockHTTPClient.swift
//  TheGoodCornerTests
//
//  Created by Moez bachagha on 11/10/2026.
//

import Foundation
import Combine
@testable import TheGoodCorner

final class MockHTTPClient: HTTPClient {
    var result: Result<Data, NetworkError> = .success(Data())
    private(set) var requests: [URLRequest] = []

    func send(_ request: URLRequest) -> AnyPublisher<Data, NetworkError> {
        requests.append(request)
        return result.publisher.eraseToAnyPublisher()
    }
}
