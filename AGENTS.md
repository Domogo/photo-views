# Project instructions

## Product and design authority

Read prd.md, PRODUCT.md, DESIGN.md, and IMPLEMENTATION_MILESTONES.md for scope.
Native macOS app: SwiftUI/AppKit, local catalog and baseline inference. Preserve originals.
The selected visual direction is Still: Atelier navigation in Graphite, with the filled Open Frame mark and sharp wordmark. The main workspace brief is under .impeccable/surfaces/.

## Delivery

The user authorized a private GitHub repository on their personal profile and periodic pushes of verified logical chunks to main. Keep photo fixtures, model weights, catalogs, caches, credentials, generated probe reports, and local decision-server artifacts out of version control.

GitHub is code storage only: no builds, hosting, CI/CD, GitHub Actions, or paid services. Build and check locally. Do not configure billable infrastructure.

## Personal repositories: no custom GitHub Actions

Never create, install, enable, or re-enable custom GitHub Actions workflows in personal repositories (including Domogo and usevoro/voro) without an explicit request for that specific workflow. This includes CI, tests, builds, scheduled jobs, releases, and Copilot automation. Run checks locally. Do not enable paid GitHub automation or raise spending budgets without an explicit request.

## Tool execution

Keep orchestration and result processing in code mode. Use host scripts for filesystem/library/computation work. Parallelize independent reads; sequence dependent actions and shared mutations. Await required results and preserve failures. Pass structured data or quote for the target language. Resume operations using their matching tool and handle; reuse evidence and back off unchanged polls.
