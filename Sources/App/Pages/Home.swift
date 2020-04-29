//
//  home.swift
//  App
//
//  Created by Sven A. Schmidt on 17/10/2018.
//

import Foundation


struct ExportConnectionDescription {
    let source: String
    let target: String
}


func homePage() -> HTML.Node {
    let title = "Swift Package Index"
    return .html([
        myhead(title: title),
        .body([
            container([
                row([
                    .h2([.text(title)]),
                    ]),
                reconcileButton(),
            ]),
        ])
    ])
}


func reconcileButton() -> HTML.Node {
    return .form([.action => "/packages/run/reconcile", .method => "get"], [
        row([
            .label(["Reconcile the master package list with the Package Index."]),
            ]),
        row([
            .input([.class => "btn btn-primary", .type => "submit", .value => "Reconcile"])
            ]),
        ])
}
