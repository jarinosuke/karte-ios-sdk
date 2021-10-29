//
//  Copyright 2020 PLAID, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import KarteUtilities
import UIKit

public struct Screen: Codable {
    /// スクリーン幅
    @CodableInjectedForObjcCompatibility(name: "screen.width")
    public var width: CGFloat

    /// スクリーン高
    @CodableInjectedForObjcCompatibility(name: "screen.height")
    public var height: CGFloat

    init() {
    }
}

extension Resolver {
    static func registerScreen() {
        register(CGFloat.self, name: "screen.width") {
            min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        }
        register(CGFloat.self, name: "screen.height") {
            max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        }
    }
}
