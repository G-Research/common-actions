# publish-nuget

A GitHub Action which pushes a package to NuGet.org, and also performs [GitHub artifact attestation](https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds) on the result.

If there's already a package in NuGet with that ID and version number, the job will detect this and do no further work: it will pass successfully without attempting an artifact attestation.
It will *not* verify that the remote artifact is identical to the one that the pipeline built, because NuGet [still does not support reproducible packs](https://github.com/NuGet/Home/issues/6229).

After this action has run successfully, you should be able to NuGet install the package at the published version, and verify the attestation corresponding to the `.nupkg` file in your NuGet cache.

Preconditions:
* You're running in an image which contains a POSIX shell.
* `dotnet` is on the path, or else has been provided through the `dotnet:` input.
* The GitHub token in scope has `attestations: write`, `id-token: write`, and `contents: read`.

An example invocation is as follows.
Notice the recommended pattern of running in an environment (here, `main-deploy`) which is the *only* environment with access to the `NUGET_API_KEY` secret,
and the corresponding `if` clause preventing this step from running except on the main branch of the source repository.

```yaml
publish-nuget:
  runs-on: ubuntu-latest
  if: ${{ !github.event.repository.fork && github.ref == 'refs/heads/main' }}
  needs: [all-required-checks-complete]
  environment: main-deploy
  permissions:
    id-token: write
    attestations: write
    contents: read
  steps:
    - uses: actions/checkout@v4
    - name: Set up .NET
      uses: actions/setup-dotnet@v4
    # An earlier build step has produced this and run the tests.
    - name: Download NuGet artifact
      uses: actions/download-artifact@v4
      with:
        name: nuget-package-plugin
        path: packed
    - name: Publish NuGet package
      uses: G-Research/common-actions/publish-nuget@main
      with:
        package-name: ApiSurface
        nuget-key: ${{ secrets.NUGET_API_KEY }}
        nupkg-dir: packed/
```

# Inputs

## `package-name`

String name of the NuGet package, e.g. the string "ApiSurface" corresponding to `https://www.nuget.org/packages/ApiSurface`.

## `nuget-key`

A NuGet API key which has permission to push new versions of the package with the given `package-name`.

## `nupkg-dir`

The directory on disk within which, at the top level, contains the `${package-name}.{some-version-number}.nupkg` file to upload.
Make sure there's only one nupkg file with any given package name in here: don't have multiple versions of the same package, because our behaviour is not defined in that case.

## `dotnet` (optional)

The path to the `dotnet` executable.
(At least one consumer of this action uses Nix flakes to lock the build environment, and it doesn't seem to be trivial to launch an action within a devshell; this piece of flexibility allows such consumers to continue using this action.)

# Troubleshooting

## "Unable to get `ACTIONS_ID_TOKEN_REQUEST_URL` env variable"

You've run the action with a GitHub cred with insufficient perms.

```
my-job-name:
  permissions:
    id-token: write
    pages: attestations: write
    contents: read
  steps:
    # ...
```

(Note that it's good practice to run as little code as possible within this elevated-privilege scope; hence, for example, the pattern in the main example where we download the `.nupkg` from an earlier stage rather than building it in the presence of the elevated `GITHUB_TOKEN`.)
