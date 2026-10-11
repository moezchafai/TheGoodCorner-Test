//
//  Publisher+Sync.swift
//  TheGoodCornerTests
//
//  Created by Moez bachagha on 11/10/2026.
//

import Foundation
import Combine

// Lit le résultat d'un publisher qui émet de façon synchrone (c'est le cas de nos mocks).
func syncResult<P: Publisher>(of publisher: P) -> Result<P.Output, P.Failure> {
    var result: Result<P.Output, P.Failure>?
    let cancellable = publisher.sink(
        receiveCompletion: { completion in
            if case .failure(let error) = completion { result = .failure(error) }
        },
        receiveValue: { value in result = .success(value) }
    )
    cancellable.cancel()
    guard let result else { fatalError("Le publisher n'a rien émis de façon synchrone") }
    return result
}
