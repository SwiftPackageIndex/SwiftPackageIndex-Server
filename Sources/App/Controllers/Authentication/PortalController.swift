//
//  PortalController.swift
//  
//


import Fluent
import Plot
import Vapor

enum PortalController {
    @Sendable 
    static func show(req: Request) async throws -> HTML {
        return Portal.View(path: req.url.path).document()
    }
}
