# everyDock Documentation

Baseline: **v0.4.0 / 2026-09-11 / public beta**. Current specifications are English and describe the implemented contract, with verification recorded separately. Targets are not reported as measured achievements.

| Document | Purpose | Audience |
|---|---|---|
| [MRD](MRD.md) | Problem, users, alternatives, and validation hypotheses. | Product owner |
| [PRD](PRD.md) | Experience, scope, priorities, and acceptance. | Product, design, engineering |
| [SRS](SRS.md) | Implementable behavior, data, state, and failure handling. | Engineering, QA |
| [TC](TC.md) | Stable test IDs, procedures, and expected results. | Engineering, QA |
| [Releasing](RELEASING.md) | Packaging, GitHub releases, and the Homebrew tap. | Maintainers |
| [v0.4.0 QA](QA-v0.4.0.md) | Tests actually performed and remaining checks. | Reviewers, testers |

## Traceability

Keep IDs stable; do not delete or reuse retired IDs. Update implementation and tests with requirement changes. Record failures rather than quietly lowering acceptance criteria.

| Market | Product | Software | Tests |
|---|---|---|---|
| MR-01: access on each screen | P-01 | FR-01/02 | TC-M01–05 |
| MR-02: familiar interaction | P-02 | FR-03–07 | TC-A05/09/11/13/14, TC-M06–11 |
| MR-02: zoomed work area | P-02 | FR-23 | TC-A27–29/32–35/37, TC-M44/45 |
| MR-04: Apps browser | P-04 | FR-22 | TC-A30/31, TC-M43 |
| MR-03: native Dock recovery | P-03 | FR-08/09 | TC-A07/10, TC-M12–15 |
| MR-04: file access | P-04 | FR-10–13/25 | TC-A36/42/43, TC-M16–22/47/55 |
| MR-05: window selection | P-05 | FR-14/15 | TC-A12/18–20/26/50/51, TC-M23–27/35/41/65 |
| MR-05: window closing | P-09 | FR-20 | TC-A23–25, TC-M38–40 |
| MR-02: menus and labels | P-02 | FR-21/24 | TC-A21/22/39, TC-M34/37/46/48–52 |
| MR-06: user control | P-06 | FR-16–18/26–29 | TC-A04/06/40/41/44–49, TC-M28–33/53/54/56–63 |
| MR-07: distribution | P-07 | FR-19/30 | TC-R01–08, TC-M64 |
| MR-08: local data | P-08 | NFR-04/05 | TC-M09/20–27, TC-P04 |
| MR-09: English presentation | P-10 | FR-31 | TC-M66, TC-R09 |

## Reading results

- **Implemented:** a code path exists; not proof of success on a physical device.
- **PASS:** observed in the specified environment and procedure.
- **PARTIAL:** only part of the case was exercised.
- **BLOCKED:** a specific missing condition prevented execution.
- **NOT RUN:** no execution evidence yet.

The suite currently contains 49 executable tests. Default runs omit the opt-in Quick Look integration; enabling it runs all 49. Test IDs include retired and historically grouped cases, so their highest number is not the test count. Legacy DockLayout tests are pure geometry checks rather than runtime multi-display UI tests.

Historical QA and release records retain their original language and scope. Start at [QA.md](../QA.md) or the version links in [TC](TC.md). Prior PASS results do not establish full v0.4.0 verification.

The app remains an ad-hoc signed beta. Complete signing/notarization, permission-enabled workflows, restoration/file safety, and the device/performance matrix before claiming stable release readiness. Code and docs follow [AGENTS.md](../AGENTS.md).
