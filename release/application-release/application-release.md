# Releasing an Application

This guide describes a small, repeatable manual release process for DKS applications. It records exactly what users received without introducing semantic versioning, GitHub Releases or a CI/CD release pipeline.

Application-specific build, deployment and smoke-test instructions remain in the application's repository.

## Release identity

Each application has a monotonically increasing global release number, beginning at 1.

A release is identified by:

- application identifier;
- global release number;
- UTC release date;
- exact Git commit.

For Blagger, release-note headings use:

```markdown
# Release 1 - 10 September 2026 UTC
```

Annotated Git tags use:

```text
BLG-1-2026-09-10-UTC
```

The general tag format is:

```text
<APPLICATION>-<GLOBAL-RELEASE-NUMBER>-<YYYY-MM-DD>-UTC
```

The release number supplies a strict total ordering, including when several releases occur on the same UTC date. Times are therefore omitted from headings and tags.

The release-note heading and tag must contain the same release number and UTC date.

## Issue discipline

All planned work should have an issue, including documentation and internal operational changes completed separately from another issue. Commit messages should include the issue identifier and preferably use the issue title as their first line.

The first paragraph of an issue should be a concise, user-facing description of its outcome. It should make sense when adapted into release notes without relying on implementation detail.

Apply the `internal-only` label when an issue should remain traceable through issues and commits but should not appear in release notes. Examples include maintaining an internal guide or changing a developer-only procedure.

Do not use `internal-only` merely because implementation occurred in a shared library. Include shared-library and other-repository issues when they materially affect the released application, describing their effect on that application.

## Release-note conventions

The application's `release-notes.md` contains successful releases in strict reverse release-number order.

Each release section contains:

1. A level-one release heading.
2. Linked issue titles.
3. One terse, user-facing paragraph per issue.
4. A hidden `release-state` HTML comment.

Use third-person present tense:

- `Allows users to...`
- `Shows...`
- `Prevents...`
- `Fixes a bug where...`

List an issue once even when commits bearing its identifier appear in several repositories. Link its title to the issue in its owning repository.

The hidden state records the application tag and the precise revisions of associated repositories:

```markdown
<!--
release-state:
  application: BLG-1-2026-09-10-UTC
  app-user: <COMMIT-SHA>
  database-access: <COMMIT-SHA>
  webapp-core: <COMMIT-SHA>
  configuration: <COMMIT-SHA>
-->
```

HTML comments remain available in the generated HTML source but are not displayed in the rendered document.

## Prepare the candidate

1. Confirm the intended release scope.
2. Complete and close the included issues.
3. Confirm the application and associated repositories contain the intended revisions.
4. Confirm the application working tree is clean.
5. Update the local release branch from its remote without discarding local work.
6. Read the newest entry in `release-notes.md` and provisionally allocate the next global release number.
7. Generate or update the new release-note section using the release-notes prompt.
8. Review every entry for correctness, completeness and user-facing wording.
9. Confirm issues labelled `internal-only` are absent.
10. Confirm the new section is first and all sections remain in strict descending release-number order.
11. Commit the release notes and any remaining release-specific changes.

The proposed release number is not consumed yet. A failed candidate retains the same proposed number.

## Build the exact candidate

Record the candidate commit:

```bash
git status --short
git rev-parse HEAD
```

The status output must be empty.

Run the application's clean build and complete automated test suite. For example:

```bash
./gradlew clean build
```

Use the application's documented command when it differs.

If the build or tests fail:

1. Do not tag the commit.
2. Do not notify users.
3. Correct the problem.
4. Amend the proposed release-note section if its contents or UTC date changed.
5. Commit the correction.
6. repeat the clean build against the new exact commit.

Do not create another release section or consume another release number for an unsuccessful candidate.

## Deploy and verify

Push the successfully built candidate commit:

```bash
git push origin <BRANCH>
```

Deploy that exact commit using the application's deployment guide. Do not deploy an uncommitted working tree or a different branch head.

Perform the application's production smoke test. At minimum, verify:

- the application starts and remains healthy;
- sign-in and sign-out work where applicable;
- one principal read workflow works;
- one principal write workflow works without damaging production data;
- the deployed revision is the intended candidate commit;
- logs contain no unexpected errors or private submitted values.

If deployment or smoke testing fails, do not tag or notify users. Correct the candidate and reuse its proposed release number.

## Tag the successful release

After the exact candidate has passed its clean build and production smoke test, create an annotated tag on that commit:

```bash
git tag -a BLG-1-2026-09-10-UTC <COMMIT-SHA> -m "BLG release 1 - 10 September 2026 UTC"
```

Inspect it before pushing:

```bash
git show --stat BLG-1-2026-09-10-UTC
git rev-list -n 1 BLG-1-2026-09-10-UTC
```

Confirm that it identifies the exact built and deployed commit, then push it:

```bash
git push origin BLG-1-2026-09-10-UTC
```

Never move or replace a pushed release tag. If a problem is discovered after the tag is pushed or users are notified, preserve the release as history and make the correction under the next release number.

## Notify users

Notify affected users only after deployment, smoke testing and tag publication succeed.

Keep the notification proportionate to the audience. It should normally contain:

- the release number and UTC date;
- a link to the applicable release-note section or file;
- any action users need to take;
- any known limitation worth calling out.

Once users have been notified, the release number is consumed.

If nobody requires an individual notification, recording and publishing the successful tagged release is the equivalent completion point. Do not leave a successfully deployed version indefinitely recorded as an unconsumed candidate.

## Final checks

- The release-note heading and tag agree.
- The tag identifies the exact commit that passed the clean build and production smoke test.
- The new release-note section is first.
- Release sections are in strict descending release-number order.
- The hidden state records all associated repository revisions.
- Issues labelled `internal-only` are absent.
- The release tag is present on the remote.
- Users have been notified where required.
- Failures and follow-up work have issues.
