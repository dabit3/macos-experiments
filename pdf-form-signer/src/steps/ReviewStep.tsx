import { CheckIcon } from '../components/Field'
import { engagementLabel, formatLongDate, formatMoney, paymentLabel, rateSuffix, stateName } from '../lib/format'
import type { FormApi } from '../lib/formApi'
import type { PdfResult } from '../lib/pdf'
import { FIELD_LABELS, FIELD_STEP } from '../lib/validation'
import { CLIENT, STEPS } from '../types'
import type { RequirementKey, SignatureImage } from '../types'

interface ReviewStepProps {
  form: FormApi
  missing: RequirementKey[]
  onJumpTo: (key: RequirementKey) => void
  onGenerate: () => void
  generating: boolean
  result: PdfResult | null
}

function Value({ value, fallback = 'Not provided' }: { value: string; fallback?: string }) {
  return value ? <dd>{value}</dd> : <dd className="is-missing">{fallback}</dd>
}

function Sig({ img, label, small }: { img: SignatureImage | null; label: string; small?: boolean }) {
  return img ? (
    <img className={`review-sig__img ${small ? 'review-sig__img--small' : ''}`} src={img.dataUrl} alt={label} />
  ) : (
    <div className="review-sig__missing">{label} missing</div>
  )
}

export function ReviewStep({ form, missing, onJumpTo, onGenerate, generating, result }: ReviewStepProps) {
  const v = form.values
  const s = form.signatures
  const ready = missing.length === 0
  const address = [v.street, [v.city, v.state && stateName(v.state), v.zip].filter(Boolean).join(', ')].filter(Boolean).join(' · ')

  return (
    <div className="review">
      {ready ? (
        <div className="review__banner review__banner--ok" role="status">
          <span className="review__banner-icon">
            <CheckIcon stroke="#fff" />
          </span>
          <div>
            <h3>Everything is complete</h3>
            <p>All required fields, both sets of initials and the signature are in place. You can generate the PDF.</p>
          </div>
        </div>
      ) : (
        <div className="review__banner review__banner--missing" role="alert">
          <span className="review__banner-icon">!</span>
          <div>
            <h3>
              {missing.length} required {missing.length === 1 ? 'item needs' : 'items need'} attention
            </h3>
            <p>Fix the highlighted items below before generating the PDF. Click one to jump straight to it.</p>
          </div>
        </div>
      )}

      {!ready && (
        <ul className="missing-list" aria-label="Missing required fields">
          {missing.map((key) => (
            <li key={key}>
              <button type="button" className="missing-item" onClick={() => onJumpTo(key)} data-missing={key}>
                <span className="missing-item__dot" aria-hidden="true" />
                <span className="missing-item__text">
                  <span className="missing-item__label">{FIELD_LABELS[key]}</span>
                  <span className="missing-item__why">{form.errors[key]}</span>
                </span>
                <span className="btn btn--ghost btn--sm">Go to {STEPS.find((st) => st.id === FIELD_STEP[key])?.label}</span>
              </button>
            </li>
          ))}
        </ul>
      )}

      <div className="review-grid">
        <section className="review-card">
          <div className="review-card__head">
            <h3>Contractor</h3>
          </div>
          <dl>
            <div>
              <dt>Full name</dt>
              <Value value={v.fullName.trim()} />
            </div>
            <div>
              <dt>Business name</dt>
              <Value value={v.company.trim()} fallback="Sole proprietor" />
            </div>
            <div>
              <dt>Email</dt>
              <Value value={v.email.trim()} />
            </div>
            <div>
              <dt>Phone</dt>
              <Value value={v.phone.trim()} />
            </div>
            <div className="review-card__full">
              <dt>Address</dt>
              <Value value={address} />
            </div>
          </dl>
        </section>

        <section className="review-card">
          <div className="review-card__head">
            <h3>Engagement</h3>
          </div>
          <dl>
            <div>
              <dt>Start date</dt>
              <Value value={formatLongDate(v.startDate)} />
            </div>
            <div>
              <dt>End date</dt>
              <Value value={formatLongDate(v.endDate)} />
            </div>
            <div>
              <dt>Engagement type</dt>
              <Value value={engagementLabel(v.engagementType)} />
            </div>
            <div>
              <dt>Fee</dt>
              <Value value={v.rate.trim() ? `${formatMoney(v.rate)}${rateSuffix(v.engagementType)}` : ''} />
            </div>
            <div>
              <dt>Payment terms</dt>
              <Value value={paymentLabel(v.paymentTerms)} />
            </div>
            <div>
              <dt>Acknowledgements</dt>
              <dd>
                {v.acceptIp ? <span className="ok">IP assigned</span> : <span className="is-missing">IP not acknowledged</span>}
                {' · '}
                {v.acceptConfidentiality ? (
                  <span className="ok">Confidentiality</span>
                ) : (
                  <span className="is-missing">Confidentiality not acknowledged</span>
                )}
                {v.acceptUpdates ? ' · Updates opted in' : ''}
              </dd>
            </div>
            {v.notes.trim() && (
              <div className="review-card__full">
                <dt>Additional terms</dt>
                <dd>{v.notes.trim()}</dd>
              </div>
            )}
          </dl>
        </section>

        <section className="review-card">
          <div className="review-card__head">
            <h3>Signature</h3>
          </div>
          <div className="review-sig">
            <Sig img={s.signature} label="Signature" />
            <dl className="review-sig__meta">
              <div>
                <dt>Signed by</dt>
                <Value value={v.fullName.trim()} />
              </div>
              <div>
                <dt>Date signed</dt>
                <Value value={formatLongDate(v.signDate)} />
              </div>
              <div>
                <dt>Method</dt>
                <dd>{s.signature ? (s.signature.mode === 'drawn' ? `Drawn, ${s.signature.strokes} ${s.signature.strokes === 1 ? 'stroke' : 'strokes'}` : 'Typed') : '—'}</dd>
              </div>
            </dl>
          </div>
        </section>

        <section className="review-card">
          <div className="review-card__head">
            <h3>Initials</h3>
          </div>
          <div className="review-sig">
            <div>
              <div className="review-sig__label">Page 1</div>
              <Sig img={s.initialsPage1} label="Initials page 1" small />
            </div>
            <div>
              <div className="review-sig__label">Page 2</div>
              <Sig img={s.initialsPage2} label="Initials page 2" small />
            </div>
          </div>
        </section>
      </div>

      <div className="generate">
        <div className="generate__text">
          <h3>Generate the signed PDF</h3>
          <p>
            A letter-size PDF for {CLIENT.name} with every value, your signature, page initials and the audit trail. It downloads
            straight to your browser’s Downloads folder.
          </p>
        </div>
        <button type="button" className="btn btn--primary btn--lg" onClick={onGenerate} disabled={!ready || generating} data-action="generate">
          {generating ? 'Generating…' : 'Generate PDF'}
        </button>
      </div>

      {result && (
        <div className="generate__result" role="status">
          <CheckIcon />
          <span>
            Downloaded <code>{result.fileName}</code> · {result.pages} pages · {(result.bytes / 1024).toFixed(0)} KB · Document{' '}
            <code>{result.documentId}</code>
          </span>
        </div>
      )}
    </div>
  )
}
