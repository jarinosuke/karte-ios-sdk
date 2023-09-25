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

import Foundation

internal struct ClassLoader {
    static var compoingViewClass: AnyClass? {
        load("V0tDb21wb3NpdGluZ1ZpZXc=")
    }

    static var remoteViewClass: AnyClass? {
        load("X1VJUmVtb3RlVmlldw==")
    }

    static var remoteKeyboardWindowClass: AnyClass? {
        load("VUlSZW1vdGVLZXlib2FyZFdpbmRvdw==")
    }

    static func load(_ name: String) -> AnyClass? {
        Data(base64Encoded: name, options: .ignoreUnknownCharacters).flatMap {
            String(data: $0, encoding: .utf8)
        }.flatMap {
            NSClassFromString($0)
        }
    }
}
