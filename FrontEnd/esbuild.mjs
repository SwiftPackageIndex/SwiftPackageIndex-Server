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

import * as esbuild from 'esbuild'
import { sassPlugin } from 'esbuild-sass-plugin'

try {
    const context = await esbuild.context({
        entryPoints: ['FrontEnd/main.js', 'FrontEnd/main.scss', 'FrontEnd/docc.scss'],
        outdir: 'Public',
        bundle: true,
        sourcemap: true,
        minify: true,
        plugins: [sassPlugin()],
        external: ['/images/*'],
    })

    if (process.argv.includes('--watch')) {
        // Watch forever!
        await context.watch()
        await new Promise(() => {})
    } else {
        await context.rebuild()
        await context.dispose()
    }
} catch {
    process.exit(1)
}
