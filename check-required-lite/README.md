# check-required-lite

A GitHub Action which checks if the given steps have completed successfully.

By contrast with [check-required](https://github.com/G-Research/common-actions/tree/d8575b4a7ce45a5735363734f4bcf640e46aee1b/check-required),
this action does not require a GitHub app.

You must call the action as follows.
The `if` clause is essential, as is the `needs-context`.
The only part of this invocation which you vary is the contents of the `needs:` list.

```yaml
all-required-checks-complete:
  needs: [some-previous-step, another-step]
  if: ${{ always() }}
  runs-on: ubuntu-latest
  steps:
    - uses: G-Research/common-actions/check-required-lite@main
      with:
        needs-context: ${{ toJSON(needs) }}
```

# Inputs

## `needs-context`

You must supply this, and you should always supply it as `${{ toJSON(needs) }}`.
This is how the action knows which steps we depended on.

# Why?

Because [required status checks are not actually required](https://emmer.dev/blog/skippable-github-status-checks-aren-t-really-required/).
This action works around this by demanding that you call it with `if: ${{ always() }}`, so it really *is* required.
