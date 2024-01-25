// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import App

extension BlogActions.Model {

    static var mock: Self {
        .init(summaries: ["one", "two", "three"].map { PostSummary.mock(postNumber: $0) })
    }

}

extension BlogActions.Model.PostSummary {
    static func mock(postNumber: String = "one") -> Self {
        .init(slug: "post-\(postNumber)",
              title: "Post \(postNumber) title",
              summary: "Post \(postNumber) summary. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vestibulum ut ante vel diam sagittis hendrerit id eget nunc. Proin non ex eget dolor tristique lacinia placerat et turpis. In dui dui, malesuada eu lectus nec, rhoncus feugiat nisi. Fusce pulvinar neque quis rutrum ullamcorper. Aliquam erat volutpat. Aliquam et molestie velit. Suspendisse sollicitudin arcu lorem, tristique iaculis quam lobortis non. Vivamus in euismod velit. Proin justo arcu, placerat ac sapien sed, tempus aliquet ligula.  Pellentesque ultricies, diam eget porta maximus, massa metus sagittis tellus, in vehicula elit erat sed metus. In mattis arcu imperdiet placerat vehicula. Vestibulum elementum iaculis tortor, sed feugiat ante posuere quis. Sed hendrerit, nisl ut tristique tincidunt, odio neque interdum ex, eget consectetur lectus dui eget felis. Donec in viverra lectus. Nunc fringilla molestie nibh ac iaculis. Morbi ac risus ut tellus posuere laoreet. Donec vehicula non sapien et mattis. Phasellus iaculis lacinia ipsum, eget congue nisl ornare ac. Vestibulum nec nibh suscipit, facilisis risus id, sollicitudin quam. Pellentesque eu quam quis magna sollicitudin consequat ac varius massa. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Suspendisse et quam dui.  Nunc dapibus erat vel elementum facilisis. Quisque mollis, lacus sit amet tincidunt egestas, nunc purus viverra eros, ut vestibulum eros eros nec nulla. Morbi ultrices, arcu non volutpat tincidunt, orci justo commodo mi, vel scelerisque odio turpis nec velit. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Pellentesque luctus a nisi tristique ullamcorper. Nunc fermentum lorem eget augue eleifend interdum.",
              publishedAt: .t0,
              published: true)
    }
}
