import {createRequire} from 'node:module'
import {resolve} from 'node:path'

const [input, output, dependencyDir] = process.argv.slice(2)
if (!input || !output || !dependencyDir)
    throw new Error('usage: node tools/prepare_m2_visual.mjs <packed.glb> <prepared.glb> <npm-prefix>')

const require = createRequire(resolve(dependencyDir, 'package.json'))
const {NodeIO} = require('@gltf-transform/core')
const {compactPrimitive, prune} = require('@gltf-transform/functions')
const io = new NodeIO()
const doc = await io.read(input)
const root = doc.getRoot()
const model = root.listNodes().find(node => node.getName() === 'Main_low001')
const [gun, mixed] = model.getMesh().listPrimitives()
if (gun.getMaterial().getName() !== 'T_BrowningM2_01' || mixed.getMaterial().getName() !== 'T_BrowningM2_02')
    throw new Error('Unexpected M2 material split')

// Weld positions for connectivity only. Keep the source vertex attributes and UV seams.
const indices = mixed.getIndices().getArray()
const positions = mixed.getAttribute('POSITION').getArray()
const matrix = model.getWorldMatrix()
const count = positions.length / 3
const points = []
const parents = new Uint32Array(count)
const welds = new Map()
function find(index) {
    while (parents[index] !== index) {
        parents[index] = parents[parents[index]]
        index = parents[index]
    }
    return index
}
for (let i = 0; i < count; i++) {
    const [x, y, z] = positions.subarray(i * 3, i * 3 + 3)
    const point = [0, 1, 2].map(axis =>
        matrix[axis] * x + matrix[axis + 4] * y + matrix[axis + 8] * z + matrix[axis + 12])
    points.push(point)
    const key = point.map(component => Math.round(component * 1e5)).join(',')
    parents[i] = welds.get(key) ?? i
    welds.set(key, parents[i])
}
for (let i = 0; i < indices.length; i += 3) {
    parents[find(indices[i + 1])] = find(indices[i])
    parents[find(indices[i + 2])] = find(indices[i])
}
const boundsByComponent = new Map()
for (const [i, [x, y]] of points.entries()) {
    const component = find(i)
    const bounds = boundsByComponent.get(component) ?? {minX: x, maxX: x, minY: y, maxY: y}
    bounds.minX = Math.min(bounds.minX, x)
    bounds.maxX = Math.max(bounds.maxX, x)
    bounds.minY = Math.min(bounds.minY, y)
    bounds.maxY = Math.max(bounds.maxY, y)
    boundsByComponent.set(component, bounds)
}
const stationary = new Set()
for (const [component, bounds] of boundsByComponent) {
    const legOrBrace = bounds.maxY <= 0.237
    const centreMount = bounds.minY < 0.24 && bounds.maxY < 0.297 && bounds.minX > -0.01 && bounds.maxX < 0.30
    if (legOrBrace || centreMount)
        stationary.add(component)
}

const movingIndices = []
const tripodIndices = []
for (let i = 0; i < indices.length; i += 3) {
    const target = stationary.has(find(indices[i])) ? tripodIndices : movingIndices
    target.push(indices[i], indices[i + 1], indices[i + 2])
}
if (movingIndices.length === 0 || tripodIndices.length === 0)
    throw new Error('Expected both moving and stationary triangles')

function extractPrimitive(name, selected) {
    const accessor = doc.createAccessor(name)
        .setType('SCALAR')
        .setBuffer(mixed.getIndices().getBuffer())
        .setArray(new indices.constructor(selected))
    const primitive = mixed.clone().setIndices(accessor)
    // compactPrimitive remaps and rewrites attributes. Clone the data to keep the other split intact.
    for (const semantic of mixed.listSemantics()) {
        const original = mixed.getAttribute(semantic)
        primitive.setAttribute(semantic, original.clone().setArray(original.getArray().slice()))
    }
    compactPrimitive(primitive)
    return primitive
}

const gunMesh = doc.createMesh('M2Gun').addPrimitive(gun.clone()).addPrimitive(extractPrimitive('MovingIndices', movingIndices))
const tripodMesh = doc.createMesh('M2Tripod').addPrimitive(extractPrimitive('TripodIndices', tripodIndices))
const scene = root.getDefaultScene() ?? root.listScenes()[0]
for (const child of scene.listChildren()) scene.removeChild(child)

const crown = [1.297886, 0.317387, 0.000427]
const swivelX = 0.148
const scale = 1.2 / (crown[0] - swivelX)
const tripodYScale = 0.724 / (0.2966 - (-0.006773))
const rotation = [0, Math.SQRT1_2, 0, Math.SQRT1_2]
function addPart(name, mesh, translation, verticalScale) {
    const part = doc.createNode(name).setTranslation(translation).setRotation(rotation).setScale([scale, verticalScale, scale])
    part.addChild(doc.createNode(name + 'Mesh').setMatrix(matrix).setMesh(mesh))
    scene.addChild(part)
}
// Part transforms are local to their actual game parents. The shared mount has no collision.
addPart('M2Gun', gunMesh, [-scale * crown[2], -scale * crown[1], scale * swivelX], scale)
addPart('M2Tripod', tripodMesh, [-scale * crown[2], 0.006773 * tripodYScale, scale * swivelX], tripodYScale)

await doc.transform(prune())
await io.write(output, doc)
console.log(JSON.stringify({gun_triangles: (gunMesh.listPrimitives()[0].getIndices().getCount() + movingIndices.length) / 3,
    tripod_triangles: tripodIndices.length / 3}))
