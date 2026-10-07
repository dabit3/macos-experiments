import { jsPDF } from 'jspdf'
import { CLIENT } from '../types'
import type { AuditEvent, FormValues, Signatures } from '../types'
import { engagementLabel, formatLongDate, formatMoney, formatTimestamp, paymentLabel, rateSuffix, stateName } from './format'

const PAGE_W = 612
const PAGE_H = 792
const MARGIN = 60
const CONTENT_W = PAGE_W - MARGIN * 2
const INK = '#1b2a4a'
const MUTED = '#6b7280'
const RULE = '#c9ced8'

export interface PdfResult {
  blob: Blob
  fileName: string
  pages: number
  bytes: number
  documentId: string
}

export function makeDocumentId(seed: string): string {
  let h = 0x811c9dc5
  for (let i = 0; i < seed.length; i++) {
    h ^= seed.charCodeAt(i)
    h = Math.imul(h, 0x01000193) >>> 0
  }
  return `CA-${h.toString(16).toUpperCase().padStart(8, '0')}`
}

function withArticle(noun: string): string {
  return `${/^([aeiou]|hour)/.test(noun) ? 'an' : 'a'} ${noun}`
}

/** jsPDF's built-in fonts only cover WinAnsi; map common symbols and drop the rest. */
function latin1(text: string): string {
  return text
    .replace(/\u2192/g, '->')
    .replace(/\u2190/g, '<-')
    .replace(/[\u2013\u2014]/g, '-')
    .replace(/[^\u0020-\u007e\u00a0-\u00ff\u2018\u2019\u201c\u201d\u2022\u2026\u20ac]/g, '?')
}

class Layout {
  doc: jsPDF
  y = MARGIN
  page = 1
  private footer: (page: number) => void

  constructor(doc: jsPDF, footer: (page: number) => void) {
    this.doc = doc
    this.footer = footer
  }

  ensure(height: number) {
    if (this.y + height > PAGE_H - MARGIN - 40) this.newPage()
  }

  newPage() {
    this.footer(this.page)
    this.doc.addPage()
    this.page += 1
    this.y = MARGIN
  }

  finish() {
    this.footer(this.page)
  }

  heading(text: string) {
    this.ensure(30)
    this.doc.setFont('helvetica', 'bold').setFontSize(11).setTextColor(INK)
    this.doc.text(text.toUpperCase(), MARGIN, this.y)
    this.y += 6
    this.doc.setDrawColor(RULE).setLineWidth(0.6).line(MARGIN, this.y, PAGE_W - MARGIN, this.y)
    this.y += 16
  }

  paragraph(text: string, size = 10, color = INK, style: 'normal' | 'bold' | 'italic' = 'normal') {
    this.doc.setFont('helvetica', style).setFontSize(size).setTextColor(color)
    const lines = this.doc.splitTextToSize(latin1(text), CONTENT_W) as string[]
    const lh = size * 1.45
    this.ensure(lines.length * lh)
    this.doc.text(lines, MARGIN, this.y)
    this.y += lines.length * lh + 6
  }

  fieldRow(pairs: [string, string][]) {
    const colW = CONTENT_W / pairs.length
    this.ensure(34)
    pairs.forEach(([label, value], i) => {
      const x = MARGIN + colW * i
      this.doc.setFont('helvetica', 'normal').setFontSize(7.5).setTextColor(MUTED)
      this.doc.text(label.toUpperCase(), x, this.y)
      this.doc.setFont('helvetica', 'normal').setFontSize(11).setTextColor(INK)
      this.doc.text(latin1(value) || '—', x, this.y + 14)
      this.doc.setDrawColor(RULE).setLineWidth(0.5).line(x, this.y + 19, x + colW - 14, this.y + 19)
    })
    this.y += 36
  }

  checkbox(checked: boolean, text: string) {
    this.doc.setFont('helvetica', 'normal').setFontSize(10).setTextColor(INK)
    const lines = this.doc.splitTextToSize(latin1(text), CONTENT_W - 20) as string[]
    const lh = 14
    this.ensure(lines.length * lh + 4)
    this.doc.setDrawColor(INK).setLineWidth(0.8).rect(MARGIN, this.y - 8, 9, 9)
    if (checked) {
      this.doc.setLineWidth(1.2)
      this.doc.line(MARGIN + 2, this.y - 3.5, MARGIN + 4, this.y - 1)
      this.doc.line(MARGIN + 4, this.y - 1, MARGIN + 7.5, this.y - 6.5)
    }
    this.doc.text(lines, MARGIN + 18, this.y)
    this.y += lines.length * lh + 6
  }
}

export function generateAgreementPdf(values: FormValues, signatures: Signatures, audit: AuditEvent[]): PdfResult {
  const doc = new jsPDF({ unit: 'pt', format: 'letter' })
  const documentId = makeDocumentId(`${values.fullName}|${values.email}|${values.signDate}`)
  const fileName = `contractor-agreement-${(values.fullName || 'unsigned').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '')}.pdf`

  const footer = (page: number) => {
    doc.setFont('helvetica', 'normal').setFontSize(8).setTextColor(MUTED)
    doc.text(`Contractor Agreement · ${documentId}`, MARGIN, PAGE_H - 32)
    doc.text(`Page ${page}`, PAGE_W - MARGIN, PAGE_H - 32, { align: 'right' })
    const initials = page === 1 ? signatures.initialsPage1 : page === 2 ? signatures.initialsPage2 : null
    if (initials) {
      const boxW = 84
      const boxH = 42
      const x = PAGE_W - MARGIN - boxW
      const y = PAGE_H - MARGIN - boxH - 4
      doc.setDrawColor(RULE).setLineWidth(0.6).rect(x, y, boxW, boxH)
      doc.addImage(initials.dataUrl, 'PNG', x + 4, y + 4, boxW - 8, boxH - 8)
      doc.setFontSize(7).setTextColor(MUTED)
      doc.text('CONTRACTOR INITIALS', x, y - 4)
    }
  }

  const L = new Layout(doc, footer)

  // ---- Title block
  doc.setFont('helvetica', 'bold').setFontSize(22).setTextColor(INK)
  doc.text('Contractor Agreement', MARGIN, L.y + 10)
  doc.setFont('helvetica', 'normal').setFontSize(9).setTextColor(MUTED)
  doc.text(`Independent contractor services agreement · Document ID ${documentId}`, MARGIN, L.y + 26)
  doc.setDrawColor(INK).setLineWidth(1.2).line(MARGIN, L.y + 36, PAGE_W - MARGIN, L.y + 36)
  L.y += 62

  L.heading('1. Parties')
  L.paragraph(
    `This Contractor Agreement (the "Agreement") is entered into as of ${formatLongDate(values.startDate) || '____________'} between ${CLIENT.name}, with offices at ${CLIENT.address} (the "Client"), and the independent contractor identified below (the "Contractor").`,
  )
  L.fieldRow([
    ['Contractor full name', values.fullName],
    ['Business name', values.company || 'Sole proprietor'],
  ])
  L.fieldRow([
    ['Email address', values.email],
    ['Phone number', values.phone],
  ])
  L.fieldRow([['Street address', values.street]])
  L.fieldRow([
    ['City', values.city],
    ['State', values.state ? `${stateName(values.state)} (${values.state})` : ''],
    ['ZIP code', values.zip],
  ])

  L.heading('2. Term')
  L.paragraph(
    `The Contractor will provide services from ${formatLongDate(values.startDate) || '____________'} (${values.startDate || '—'}) through ${formatLongDate(values.endDate) || '____________'} (${values.endDate || '—'}), unless terminated earlier in accordance with Section 6. Either party may terminate this Agreement with fourteen (14) days written notice.`,
  )
  L.fieldRow([
    ['Start date', values.startDate],
    ['End date', values.endDate],
  ])

  L.heading('3. Services')
  L.paragraph(
    'The Contractor agrees to perform the design and engineering services described in each written statement of work agreed by both parties. The Contractor determines the method, details and means of performing the services and is not an employee of the Client.',
  )

  // ---- Page 2
  L.newPage()
  L.heading('4. Compensation')
  const money = values.rate ? `${formatMoney(values.rate)}${rateSuffix(values.engagementType)}` : '—'
  L.paragraph(
    `The Client will pay the Contractor on ${withArticle((engagementLabel(values.engagementType) || '__________').toLowerCase())} basis at ${money}. Invoices are payable on ${paymentLabel(values.paymentTerms) || '______'} terms from the invoice date.`,
  )
  L.fieldRow([
    ['Engagement type', engagementLabel(values.engagementType)],
    ['Fee', money],
    ['Payment terms', paymentLabel(values.paymentTerms)],
  ])

  L.heading('5. Intellectual property & confidentiality')
  L.checkbox(
    values.acceptIp,
    'The Contractor assigns to the Client all right, title and interest in the deliverables created under this Agreement upon payment in full.',
  )
  L.checkbox(
    values.acceptConfidentiality,
    'The Contractor will keep the Client\u2019s non-public business, technical and financial information confidential for three (3) years after the end of the engagement.',
  )
  L.checkbox(values.acceptUpdates, 'The Contractor would like to receive project updates and invoices by email.')

  L.heading('6. Additional terms')
  L.paragraph(values.notes.trim() || 'No additional terms.', 10, values.notes.trim() ? INK : MUTED, values.notes.trim() ? 'normal' : 'italic')

  L.heading('7. Signatures')
  L.paragraph('By signing below, the parties agree to be bound by the terms of this Agreement.')
  L.ensure(150)
  const sigTop = L.y
  const colW = CONTENT_W / 2 - 12
  // Contractor
  doc.setFont('helvetica', 'normal').setFontSize(7.5).setTextColor(MUTED)
  doc.text('CONTRACTOR', MARGIN, sigTop)
  if (signatures.signature) {
    const h = 64
    const w = Math.min(colW, (signatures.signature.width / signatures.signature.height) * h)
    doc.addImage(signatures.signature.dataUrl, 'PNG', MARGIN, sigTop + 8, w, h)
  }
  doc.setDrawColor(INK).setLineWidth(0.8).line(MARGIN, sigTop + 78, MARGIN + colW, sigTop + 78)
  doc.setFont('helvetica', 'normal').setFontSize(10).setTextColor(INK)
  doc.text(latin1(`Name: ${values.fullName || '—'}`), MARGIN, sigTop + 94)
  doc.text(`Date signed: ${values.signDate || '—'}${values.signDate ? ` (${formatLongDate(values.signDate)})` : ''}`, MARGIN, sigTop + 110)
  doc.setFontSize(8).setTextColor(MUTED)
  doc.text(
    signatures.signature
      ? signatures.signature.mode === 'drawn'
        ? `Signature drawn with ${signatures.signature.strokes} pen stroke${signatures.signature.strokes === 1 ? '' : 's'}`
        : 'Typed signature adopted by the contractor'
      : 'Not signed',
    MARGIN,
    sigTop + 124,
  )
  // Client
  const cx = MARGIN + colW + 24
  doc.setFont('helvetica', 'normal').setFontSize(7.5).setTextColor(MUTED)
  doc.text('CLIENT', cx, sigTop)
  doc.setFont('helvetica', 'bolditalic').setFontSize(16).setTextColor(INK)
  doc.text(CLIENT.signatory.split(',')[0], cx, sigTop + 62)
  doc.setDrawColor(INK).setLineWidth(0.8).line(cx, sigTop + 78, cx + colW, sigTop + 78)
  doc.setFont('helvetica', 'normal').setFontSize(10).setTextColor(INK)
  doc.text(`Name: ${CLIENT.signatory}`, cx, sigTop + 94)
  doc.text(`On behalf of ${CLIENT.name}`, cx, sigTop + 110)
  L.y = sigTop + 140

  // ---- Certificate of completion
  L.newPage()
  doc.setFont('helvetica', 'bold').setFontSize(18).setTextColor(INK)
  doc.text('Certificate of completion', MARGIN, L.y + 8)
  doc.setFont('helvetica', 'normal').setFontSize(9).setTextColor(MUTED)
  doc.text(`Audit trail for ${documentId} · generated ${formatTimestamp(new Date().toISOString())} (local time)`, MARGIN, L.y + 24)
  doc.setDrawColor(INK).setLineWidth(1.2).line(MARGIN, L.y + 34, PAGE_W - MARGIN, L.y + 34)
  L.y += 56
  L.paragraph(
    `${audit.length} event${audit.length === 1 ? ' was' : 's were'} recorded in the browser while this document was completed. Times are shown in the signer's local time zone.`,
    9.5,
    MUTED,
  )
  const timeW = 118
  for (const ev of audit) {
    doc.setFont('helvetica', 'normal').setFontSize(9).setTextColor(INK)
    const lines = doc.splitTextToSize(latin1(ev.message), CONTENT_W - timeW) as string[]
    L.ensure(lines.length * 12 + 1)
    doc.setFont('helvetica', 'normal').setFontSize(8.5).setTextColor(MUTED)
    doc.text(formatTimestamp(ev.time), MARGIN, L.y)
    doc.setFont('helvetica', 'normal').setFontSize(9).setTextColor(INK)
    doc.text(lines, MARGIN + timeW, L.y)
    L.y += lines.length * 12 + 1
  }
  L.finish()

  const blob = doc.output('blob')
  return { blob, fileName, pages: L.page, bytes: blob.size, documentId }
}

export function downloadBlob(blob: Blob, fileName: string) {
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = fileName
  document.body.appendChild(a)
  a.click()
  a.remove()
  setTimeout(() => URL.revokeObjectURL(url), 10_000)
}
