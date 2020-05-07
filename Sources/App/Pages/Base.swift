//
//  base.swift
//  App
//
//  Created by Sven A. Schmidt on 17/10/2018.
//

import Vapor


//func render(page: HTML.Node) -> Response {
//    let res = Response(status: .ok, body: .init(string: HTML.render(page)))
//    res.headers.add(name: "Content-Type", value: "text/html")
//    return res
//}


func myhead(title: String) -> HTML.Node {
    return .head([
        .meta([.charset => "utf-8"]),
        .meta([.name => "viewport",
               .content => "width=device-width, initial-scale=1, shrink-to-fit=no"]),
        .link([.rel => "stylesheet",
               .href => "https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/css/bootstrap.min.css",
               .integrity => "sha384-MCw98/SFnGE8fJT3GXwEOngsV7Zt27NXFoaoApmYm81iuXoPkFOJwJ8ERdknLPMO",
               .crossorigin => "anonymous"]),
        .link([.href =>  "/grid.css", .rel => "stylesheet"]),
        .title(title)
        ])
}


func container(_ children: [HTML.Node]) -> HTML.Node {
    return .div([.class => "container"], children)
}


func row(_ children: [HTML.Node]) -> HTML.Node {
    return .div([.class => "row"], children)
}
