//
//  home.swift
//  App
//
//  Created by Sven A. Schmidt on 17/10/2018.
//

import Foundation


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
                ingestButton(),
            ]),
        ])
    ])
}


func reconcileButton() -> HTML.Node {
    return .form([.action => "/packages/run/reconcile", .method => "get"], [
        row([
            .input([.class => "btn btn-primary", .type => "submit", .value => "Reconcile"])
        ]),
        row([
            .label(["Reconcile the master package list with the Package Index."]),
        ]),
    ])
}


func ingestButton() -> HTML.Node {
    return .form([.action => "/packages/run/ingest", .method => "get"], [
        row([
            .input([.class => "btn btn-primary", .type => "submit", .value => "Ingest"])
        ]),
        row([
            .label(["Ingest metadata for a batch of packages."]),
        ]),
    ])
}
