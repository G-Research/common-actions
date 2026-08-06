# zizmor-autofix

Scans the repository with [zizmor](https://docs.zizmor.sh) and opens one PR per
`(audit, disposition)` bucket of automated fixes — safe fixes get the `safe-fix`
label, unsafe fixes get `needs-review`.

## Example usage

```yaml
name: zizmor autofix

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  autofix:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          persist-credentials: false

      - uses: G-Research/common-actions/zizmor-autofix@main
        with:
          # Use a PAT/app token rather than the default GITHUB_TOKEN if you want
          # the opened PRs to trigger other workflows (e.g. CI).
          github-token: ${{ secrets.ZIZMOR_PAT }}
```
