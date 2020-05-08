import Plot


func homePage() -> HTML {
    let title = "Swift Package Index"

    return HTML(
        myhead(title: title),
        .body(
            container(
                row(.h2(.text(title))),
                reconcileButton(),
                ingestButton()
            )
        )
    )
}


func reconcileButton() -> Node<HTML.BodyContext> {
    .form(
        .action("/packages/run/reconcile"),
        .method(.get),
        .input(.class("btn btn-primary"), .type(.submit), .value("Reconcile")),
        .label(.text("Reconcile the master package list with the Package Index."))
    )
}


func ingestButton() -> Node<HTML.BodyContext> {
    .form(
        .action("/packages/run/ingest"),
        .method(.get),
        .input(.class("btn btn-primary"), .type(.submit), .value("Ingest")),
        .label(.text("Ingest metadata for a batch of packages."))
    )
}
