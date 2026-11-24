import { readFile, writeFile } from 'node:fs/promises'
import { createRequire } from 'node:module'
import { join, resolve } from 'node:path'

const [workingDir, dependencyDir] = process.argv.slice(2)
if (!workingDir || !dependencyDir)
    throw new Error('Use: node tools/prepare_sgc_crate_lods.mjs <working-dir> <npm-prefix>')

const require = createRequire(resolve(dependencyDir, 'package.json'))
const { MeshoptSimplifier } = require('meshoptimizer')
await MeshoptSimplifier.ready

const source = JSON.parse(await readFile(join(workingDir, 'source.json'), 'utf8'))
const indices = Uint32Array.from(source.indices)
const positions = Float32Array.from(source.positions)
const attributes = Float32Array.from(source.attributes)
const settings = [
    { triangles: 2600, distance: 0.010, errorLimit: 0.006 },
    { triangles: 1500, distance: 0.033, errorLimit: 0.015 },
]
const levels = settings.map(({ triangles, distance, errorLimit }) => {
    const [reduced, error] = MeshoptSimplifier.simplifyWithAttributes(
        indices, positions, 3, attributes, 5, [0.20, 0.20, 0.20, 0.35, 0.35], null,
        triangles * 3, errorLimit, ['ErrorAbsolute'],
    )
    console.log(`LOD ${distance} triangles=${reduced.length / 3} error_m=${error.toFixed(6)}`)
    return { distance, indices: Array.from(reduced) }
})
await writeFile(join(workingDir, 'levels.json'), JSON.stringify(levels))
