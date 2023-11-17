//
//  DownloadDelegateBasic.swift
//  GPSDemoApp
//
//  Created by Justin Brady on 11/15/23.
//  Copyright © 2023 Justin Brady. All rights reserved.
//

import Foundation

class DownloadDelegateBasic : NSObject, DLDelegate {

    typealias DownloadCompleted = (DLDelegate, Data?)->Void

    struct Cxn {
        let task: URLSessionDownloadTask
        let doThis: DownloadCompleted
    }

    var connections: [URLSession: Cxn] = [:]

    func downloadBegin(_ doThis: @escaping DownloadCompleted) {

        //let url = URL(string: "https://www.opencurb.nyc/search.php?coord=40.7630131962117,-73.9860065204115&v_type=PASSENGER&a_type=PARK&meter=0&radius=50&StartDate=2015-09-30&StartTime=06:25&EndDate=2015-09-30&EndTime=07:25&action_allowed=1")!


        let url = URL(string: "https://www.domain17.net/index.html")!

        let req =  URLRequest(url: url)
        let config = URLSessionConfiguration.default

        let sess: URLSession = .init(configuration: config, delegate: self, delegateQueue: nil)
        let dlTask = sess.downloadTask(with: req)

        dlTask.resume()

        connections[sess] = .init(task: dlTask, doThis: doThis)
    }

}

extension DownloadDelegateBasic : URLSessionDownloadDelegate {
    func urlSession(_ sess: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        connections[sess]!.doThis(self, Data())
    }


    func urlSession(_ sess: URLSession, didFailWithError error: Error) {
        connections[sess]!.doThis(self, Data())
    }

    func urlSession(_ sess: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("\(data)")
    }

}
