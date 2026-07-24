# Data Protection Impact Assessment — Custody Alert (DRAFT)

> **STATUS: DRAFT — NOT YET IN FORCE.** This document was prepared as a working draft to be finalised and approved by a qualified Nigerian lawyer and the organisation's data-protection contact before publication or reliance. It is not legal advice.

A DPIA is required because Custody Alert processes **precise location** and data
revealing that a person may be **detained by police** — high-risk, potentially
sensitive processing.

## 1. The processing
On the user's trigger (or an unattended "Safe walk" timer), the app sends the
user's identity, timestamp, and current location to 1–3 pre-set contacts, and tells
those contacts how to help. See build-plan section 4b.

## 2. Necessity and proportionality
The purpose — getting word out when someone is taken into custody — cannot be met
without contacting someone and saying where the person is. Data is limited to what
achieves that: identity, time, coarse+precise location, chosen contacts. No
continuous tracking.

## 3. Risks and mitigations
| Risk | Mitigation |
|------|-----------|
| Location is highly sensitive | Captured only at trigger/check-in; **purged as soon as the incident closes** (retention = 0 days at rest); shared only with chosen contacts |
| Third-party contact data | Stored on-device by default, encrypted; user attests they have consent to add each contact |
| Accidental / malicious triggers | Cancellable countdown; "I'm safe" stand-down; rate limits |
| Interception | TLS in transit; capability-URL tracking token is unguessable and short-lived |
| Phone seized after trigger | Server owns delivery once accepted, so seizure does not stop the alert — but this means the server briefly holds the alert; retention limits the window |
| Function creep into surveillance | Policy: location is never used for anything but the alert; enforced by purge and by no continuous-location code path |

## 4. Lawful basis
Consent (explicit opt-in, per-contact) and, at the moment of an alert, vital
interests of the data subject.

## 5. Residual risk & decision
With the mitigations above the residual risk is **assessed as acceptable for the
benefit delivered**, subject to DPO sign-off. **[DPO SIGN-OFF — PENDING]**
