import { nodeResolve } from '@rollup/plugin-node-resolve'
import commonjs from '@rollup/plugin-commonjs'
import { terser } from 'rollup-plugin-terser'

export default {
  input: 'Resources/Scripts/main.js',
  output: {
    file: 'Public/main.js',
    sourcemap: true,
  },
  plugins: [nodeResolve(), commonjs(), terser()],
}
