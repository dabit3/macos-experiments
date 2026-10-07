#!/usr/bin/env node
// Run from draev: node scripts/computer-use-test.mjs
// All app inputs are native xdotool events. CDP only reads UI/state.
import { ComputerTest } from './computer-use-harness.mjs'

const t = await ComputerTest.open(import.meta.url)
let exported
try {
  // STEP 1 — Restore the deterministic residence through the UI.
  await t.step('Restore the 960-object sample', async () => {
    await t.click('Reset sample drawing')
    await t.clickText('Restore sample')
    await t.clickText('Home', 'nav button')
    const s = await t.state()
    await t.equal(s.drawing.entities.length, 960, 'Sample entity count')
    await t.equal(s.drawing.layers.length, 11, 'Sample layer count')
    await t.equal(s.rendered, 960, 'All sample entities rendered')
    await t.equal(s.drawing.currentLayer, 'draft', 'A-SKETCH active')
  })

  // STEP 2 — Type exact coordinates, then inspect actual Properties.
  await t.step('Draw the exact terrace rectangle', async () => {
    await t.command('RECTANGLE 12000,1900 16000,2900')
    await t.entity({
      type: 'rect', x: 12000, y: 1900, width: 4000, height: 1000,
    })
    await t.fields({ Width: '4000', Height: '1000' })
    await t.equal((await t.state()).rendered, 961, 'Rectangle added')
  })

  // STEP 3 — Commit property edits; test undo AND redo numerically.
  await t.step('Edit dimensions and verify undo / redo', async () => {
    await t.fill('Width', '4500')
    await t.fill('Position Y', '2000')
    await t.entity({ x: 12000, y: 2000, width: 4500, height: 1000 })
    await t.fields({ Width: '4500', 'Position Y': '2000' })
    await t.click('Undo')
    await t.entity({ y: 1900, width: 4500 })
    await t.fields({ 'Position Y': '1900' })
    await t.click('Redo')
    await t.entity({ y: 2000, width: 4500 })
    await t.fields({ 'Position Y': '2000' })
  })

  // STEP 4 — Move the selected rectangle and create a typed circle.
  await t.step('Move 500mm and draw a radius-600 circle', async () => {
    await t.command('MOVE 500,0')
    await t.entity({ x: 12500, y: 2000, width: 4500, height: 1000 })
    await t.fields({ 'Position X': '12500', Width: '4500' })
    await t.command('CIRCLE 18500,2500 600')
    await t.entity({ type: 'circle', cx: 18500, cy: 2500, radius: 600 })
    await t.fields({ Radius: '600' })
    await t.equal((await t.state()).rendered, 962, 'Circle added')
  })

  // STEP 5 — Toggle real planting; leave it hidden for export checks.
  await t.step('Hide / show planting and verify visible counts', async () => {
    await t.fill('Search layers', 'plant', false)
    await t.click('Hide L-PLANT')
    await t.layer('landscape', false, 584)
    await t.click('Show L-PLANT')
    await t.layer('landscape', true, 962)
    await t.click('Hide L-PLANT')
    await t.layer('landscape', false, 584)
    await t.fill('Search layers', '', false)
  })

  // STEP 6 — Download actual files; inspect XML, DXF pairs and JSON.
  await t.step('Export SVG / DXF / JSON and inspect contents', async () => {
    exported = (await t.state()).drawing
    await t.download('SVG drawing', 'Courtyard_Residence.svg')
    await t.download('DXF drawing', 'Courtyard_Residence.dxf')
    await t.download('Draev project', 'Courtyard_Residence.draev.json')
    await t.verifyExports(exported)
    await t.equal(t.readJSON('Courtyard_Residence.draev.json'),
      exported, 'Downloaded JSON equals all geometry and layer state')
  })

  // STEP 7 — Native reload, not a storage write or synthetic remount.
  await t.step('Reload and verify persisted drawing', async () => {
    await t.key('ctrl+r')
    await t.waitForDrawing(962)
    await t.equal((await t.state()).drawing, exported,
      'Reload preserves exported geometry, layers and hidden planting')
    await t.layer('landscape', false, 584)
    await t.equal(t.errors, [], 'No runtime / console / request failures')
  })
} catch (error) {
  t.fail(error)
  process.exitCode = 1
} finally {
  await t.finish()
}
