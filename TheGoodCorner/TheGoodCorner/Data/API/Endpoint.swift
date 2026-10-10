//
//  Endpoint.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 10/10/2026.
//


import Foundation

struct Endpoint {
    let path: String
    var queryItems: [URLQueryItem] = []

    func url(baseURL: URL) -> URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = path
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        return components?.url
    }
}

// MARK: - Endpoints prédéfinis

extension Endpoint {


    static func listings(page: Int? = nil, limit: Int? = nil, query: String? = nil) -> Endpoint {
        var items: [URLQueryItem] = []
        if let page { items.append(URLQueryItem(name: "page", value: String(page))) }
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let query, !query.isEmpty { items.append(URLQueryItem(name: "query", value: query)) }
        return Endpoint(path: "/listings", queryItems: items)
    }

 
    static let categories = Endpoint(path: "/categories")
}
