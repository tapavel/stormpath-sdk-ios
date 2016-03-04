//
//  SocialLoginAPIRequestManager.swift
//  Stormpath
//
//  Created by Edward Jiang on 3/3/16.
//  Copyright © 2016 Stormpath. All rights reserved.
//

import Foundation

class SocialLoginAPIRequestManager: APIRequestManager {
    var socialProvider: StormpathSocialProvider
    var authorizationData: String // Auth code or access token
    var authorizationDataType: AuthorizationDataType
    var callback: AccessTokenCallback
    
    init(withURL url: NSURL, accessToken: String, socialProvider: StormpathSocialProvider, callback: AccessTokenCallback) {
        self.socialProvider = socialProvider
        self.authorizationData = accessToken
        self.authorizationDataType = .AccessToken
        self.callback = callback
        
        super.init(withURL: url)
    }
    
    init(withURL url: NSURL, authorizationCode: String, socialProvider: StormpathSocialProvider, callback: AccessTokenCallback) {
        self.socialProvider = socialProvider
        self.authorizationData = authorizationCode
        self.authorizationDataType = .AuthorizationCode
        self.callback = callback
        
        super.init(withURL: url)
    }
    
    override func prepareForRequest() {
        var postDictionary = ["providerData": ["providerId": socialProvider.stringValue()]]
        
        switch authorizationDataType {
        case .AuthorizationCode:
            postDictionary["providerData"]?["code"] = authorizationData
        case .AccessToken:
            postDictionary["providerData"]?["accessToken"] = authorizationData
        }
        
        request.HTTPBody = try? NSJSONSerialization.dataWithJSONObject(postDictionary, options: [])
        request.HTTPMethod = "POST"
    }
    
    override func requestDidFinish(data: NSData, response: NSHTTPURLResponse) {
        // Grab access token from cookies
        // Callback
        
        guard let cookies = urlSession.configuration.HTTPCookieStorage?.cookiesForURL(request.URL!) else {
            performCallback(error: StormpathError.APIResponseError)
            return
        }
        
        var accessToken: String?
        var refreshToken: String?
        
        for cookie in cookies {
            switch cookie.name {
            case "access_token":
                accessToken = cookie.value
            case "refresh_token":
                refreshToken = cookie.value
            default:
                break
            }
        }
        
        if accessToken != nil {
            performCallback(accessToken, refreshToken: refreshToken, error: nil)
        } else {
            performCallback(error: StormpathError.APIResponseError)
        }
    }
    
    override func performCallback(error error: NSError?) {
        performCallback(nil, refreshToken: nil, error: error)
    }
    
    func performCallback(accessToken: String?, refreshToken: String?, error: NSError?) {
        dispatch_async(dispatch_get_main_queue()) {
            self.callback(accessToken: accessToken, refreshToken: refreshToken, error: error)
        }
    }
}

enum AuthorizationDataType {
    case AccessToken, AuthorizationCode
}