const paths = {
  arrow: 'M5 12h14m-5-5 5 5-5 5',
  download: 'M12 3v12m-4-4 4 4 4-4M4 16v4h16v-4',
  shuffle: 'm4 5 4 0 8 14h4m-4-4 4 4-4 4M4 19h4l3-5m2-4 3-5h4m-4-4 4 4-4 4',
  orbit: 'M20 7c3 3-1 8-6 11S3 21 2 18s2-8 8-11 10-3 10 0ZM12 2v3m0 14v3',
  check: 'm5 12 4 4L19 6',
  undo: 'M9 14 4 9l5-5M4 9h10.5a5.5 5.5 0 0 1 0 11H11',
  redo: 'm15 14 5-5-5-5m5 5H9.5a5.5 5.5 0 0 0 0 11H13',
  chevronLeft: 'm15 18-6-6 6-6',
  chevronRight: 'm9 18 6-6-6-6',
} as const

export function Icon({ name, size = 18 }: { name: keyof typeof paths; size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d={paths[name]} />
    </svg>
  )
}
