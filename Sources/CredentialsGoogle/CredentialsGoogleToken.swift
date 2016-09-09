/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Kitura
import KituraNet
import LoggerAPI
import Credentials

import SwiftyJSON

import Foundation

public class CredentialsGoogleToken : CredentialsPluginProtocol {
    
    public var name : String {
        return "GoogleToken"
    }
    
    public var redirecting : Bool {
        return false
    }
    
    public init () {}
    
    public var usersCache : NSCache<NSString, BaseCacheElement>?
    
    public func authenticate (request: RouterRequest, response: RouterResponse,
                              options: [String:Any], onSuccess: @escaping (UserProfile) -> Void,
                              onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                              onPass: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                              inProgress: @escaping () -> Void) {
        if let type = request.headers["X-token-type"], type == name {
            if let token = request.headers["access_token"] {
                #if os(Linux)
                    let key = NSString(string: token)
                #else
                    let key = token as NSString
                #endif
                let cacheElement = usersCache!.object(forKey: key)
                if let cached = cacheElement {
                    onSuccess(cached.userProfile)
                    return
                }
                
                var requestOptions: [ClientRequest.Options] = []
                requestOptions.append(.schema("https://"))
                requestOptions.append(.hostname("www.googleapis.com"))
                requestOptions.append(.method("GET"))
                requestOptions.append(.path("/oauth2/v3/userinfo?access_token=\(token)"))
                var headers = [String:String]()
                headers["Accept"] = "application/json"
                requestOptions.append(.headers(headers))
                
                let req = HTTP.request(requestOptions) { response in
                    if let response = response, response.statusCode == HTTPStatusCode.OK {
                        do {
                            var body = Data()
                            try response.readAllData(into: &body)
                            let jsonBody = JSON(data: body)
                            if let id = jsonBody["sub"].string,
                                let name = jsonBody["name"].string {
                                let userProfile = UserProfile(id: id, displayName: name, provider: self.name)
                                if let email = jsonBody["email"].string {
                                    let userEmail = UserProfile.UserProfileEmail(value : email, type : "")
                                    userProfile.emails = [userEmail]
                                }
                                let newCacheElement = BaseCacheElement(profile: userProfile)
                                #if os(Linux)
                                    let key = NSString(string: token)
                                #else
                                    let key = token as NSString
                                #endif
                                self.usersCache!.setObject(newCacheElement, forKey: key)
                                onSuccess(userProfile)
                                return
                            }
                        } catch {
                            Log.error("Failed to read Google response")
                        }
                    }
                    onFailure(nil, nil)
                }
                req.end()
            }
            else {
                onFailure(nil, nil)
            }
        }
        else {
            onPass(nil, nil)
        }
    }
}
