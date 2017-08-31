//
//  Api.swift
//  AwesomeBlogs
//
//  Created by wade.hawk on 2017. 7. 3..
//  Copyright © 2017년 wade.hawk. All rights reserved.
//

import Foundation
import RxSwift
import Moya
import ObjectMapper
import Swinject
import RealmSwift

enum Api {
    static func getFeeds(group: AwesomeBlogs.Group, force: Bool = false) -> Single<[Entry]> {
        let remote = Service.shared.container
            .resolve(RxMoyaProvider<AwesomeBlogsRemoteSource>.self)!.singleRequest(.feeds(group: group))
            .observeOn(Service.shared.container.resolve(SerialDispatchQueueScheduler.self, name: Service.RegisterationName.cacheSave.rawValue)!)
            .do(onNext: { json in
                AwesomeBlogsLocalSource.saveFeeds(group: group, json: json)
            }).map{ try Mapper<Entry>().mapArray(JSONObject: $0["entries"].rawValue) }.asObservable()
            .observeOn(MainScheduler.instance)
        if force {
            return remote.asSingle()
        }
        return AwesomeBlogsLocalSource.getFeeds(group: group).do(onNext: { feed in
            guard feed.isExpired else { return }
            _ = remote.do(onNext: { entries in
                    GlobalEvent.shared.silentFeedRefresh.on(.next((group,entries)))
                }).subscribe()
        }).map{ feed in feed.entries.flatMap{ Entry(entryDB: $0) }
        }.ifEmpty(switchTo: remote).asSingle().observeOn(MainScheduler.instance)
    }
    static func readFeeds(link: String) -> Observable<Void> {
        return Service.shared.container.resolve(RxMoyaProvider<AwesomeBlogsRemoteSource>.self)!.request(.read(link: link)).map{ _ in }
    }
}
