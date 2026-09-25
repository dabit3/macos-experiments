import { useEffect, useState } from 'react'
import { FLAG } from '../shell/filesystem'
import { FRAME_COUNT, FRAME_MS, fireworksFrame } from '../shell/fireworks'
import { OutputLines } from './OutputLines'

const LOOPS = 4

interface Props {
  commands: number
  onSettled: () => void
}

export function Fireworks({ commands, onSettled }: Props) {
  const [tick, setTick] = useState(0)

  useEffect(() => {
    if (tick >= FRAME_COUNT * LOOPS) return
    const id = window.setTimeout(() => setTick((t) => t + 1), FRAME_MS)
    return () => window.clearTimeout(id)
  }, [tick])

  const resultVisible = tick >= FRAME_COUNT
  useEffect(() => {
    if (resultVisible) onSettled()
  }, [resultVisible, onSettled])

  const animating = tick < FRAME_COUNT * LOOPS

  return (
    <div className="fireworks" data-testid="fireworks" aria-live="polite">
      {animating && (
        <div className="fireworks-sky">
          <OutputLines lines={fireworksFrame(tick % FRAME_COUNT)} />
        </div>
      )}
      {resultVisible && (
        <div className="result">
          <div className="result-head">
            <span className="result-label">Flag accepted</span>
            <span className="result-flag">{FLAG}</span>
          </div>
          <div className="result-meta">
            Solved in {commands} command{commands === 1 ? '' : 's'}. Run <span className="result-code">history</span> to
            see them, or <span className="result-code">clear</span> to reset the screen.
          </div>
        </div>
      )}
    </div>
  )
}
