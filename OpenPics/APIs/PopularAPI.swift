//
//  PopularAPI.swift
//  OpenPics
//
//  Created by PJ Gray on 1/3/16.
//  Copyright © 2016 Say Goodnight Software. All rights reserved.
//

import Foundation
import Moya
import SwiftyJSON

// MARK: - Provider support

private extension String {
    var URLEscapedString: String {
        return self.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLHostAllowedCharacterSet())!
    }
}

public enum PopularAPI {
    case Images(query: String, page: Int)
}

extension PopularAPI: TargetType {
    public var baseURL: NSURL { return NSURL(string: "http://openpics.herokuapp.com")! }
    public var path: String {
        switch self {
        case .Images:
            return "/images"
        }
    }
    public var method: Moya.Method {
        return .GET
    }
    public var parameters: [String: AnyObject]? {
        switch self {
        case Images(let query, let page):
                return ["query":query, "page":page]
        }
    }
    
    public var sampleData: NSData {
        switch self {
        case .Images(_, _):
            return "{\"login\": \"DERP\", \"id\": 100}".dataUsingEncoding(NSUTF8StringEncoding)!
        }
    }
}

public func url(route: TargetType) -> String {
    return route.baseURL.URLByAppendingPathComponent(route.path).absoluteString
}

public class PopularProvider: MoyaProvider<PopularAPI>, ImageProvider {

    let name = "Currently Popular Images"
    let shortName = "Currently Popular Images"

    // - should the parameters on the completion handler be optional?
    // - how can i specify the name of the variable for the paramters on completion handler?
    public func getImagesWithQuery(query: String, pageNumber: Int, completionHandler: (NSArray?, Bool?) -> Void) {
        self.request(.Images(query: "",page: 0)) { result in
            switch result {
            case let .Success(response):

                let json = JSON(data: response.data)
                var images = [Image]()
                for dict in json["data"].arrayValue {
                    // I feel like this data unwrapping is wrong...?
                    let image = Image(jsonDictionary: dict.dictionaryObject!)
                    images.append(image)
                }
                
                completionHandler(images,true)
            case let .Failure(error):
                // Not handling errors here yet
                guard let error = error as? CustomStringConvertible else {
                    break
                }
                print("\(error.description)")
            }
        }
    }

    override init(endpointClosure: EndpointClosure = MoyaProvider.DefaultEndpointMapping,
        requestClosure: RequestClosure = MoyaProvider.DefaultRequestMapping,
        stubClosure: StubClosure = MoyaProvider.NeverStub,
        manager: Manager = Manager.sharedInstance,
        plugins: [PluginType] = []) {

            super.init(endpointClosure: endpointClosure, requestClosure: requestClosure, stubClosure: stubClosure, manager: manager, plugins: plugins)
    }
}