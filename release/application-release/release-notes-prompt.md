# Prompt: Generate or Update Application Release Notes

Use this prompt with ChatGPT when preparing an application release. Replace values in angle brackets before use. Blagger's current associated repositories are shown as defaults.

```text
Generate or update release-notes.md for the next successful release of <APPLICATION-NAME>.

Application repository:
- <OWNER>/<APPLICATION-REPOSITORY>

Application issue prefix:
- <APPLICATION-PREFIX>

Release files:
- <RELEASE-NOTES-PATH>
- <RELEASE-STATE-PATH>

Associated repositories:
- decani/app-user
- decani/database-access
- decani/webapp-core
- decani/configuration

Release rules:

1. Read the existing `<RELEASE-NOTES-PATH>` and `<RELEASE-STATE-PATH>` before making changes. If `<RELEASE-STATE-PATH>` does not exist, treat this as the first release using a separate state file.
2. Determine the next proposed global release number from the newest release section and `<RELEASE-STATE-PATH>`. If neither file records a release, use 1. If they disagree, report the discrepancy rather than guessing.
3. Determine the release date from the current UTC date and write it in ISO format.
4. Preserve the document's single level-one `# Release Notes` page heading and create this level-two release heading:
   ## Release <GLOBAL-RELEASE-NUMBER> - <YYYY-MM-DD>
5. Prepend the new section. Preserve all earlier sections unchanged and keep every section in strict descending global release-number order.
6. Do not include a time or timezone label in the heading or Git tag.
7. Use this proposed annotated Git tag:
   release-<GLOBAL-RELEASE-NUMBER>-<YYYY-MM-DD>
   The repository identifies the application, so do not prefix the tag with the application identifier.
8. Use this annotated tag message:
   Release <GLOBAL-RELEASE-NUMBER> - <YYYY-MM-DD>
9. If a proposed section already exists for this unreleased global release number, update that section instead of creating another one.

Select issues as follows:

1. For the initial release, inspect all closed issues in the application repository and scan the available commit history in the application and associated repositories.
2. For subsequent releases, read documents/release-state.yml and inspect commits after the recorded application release and associated-repository revisions.
3. Extract issue identifiers from all lines of commit messages, not only their subjects.
4. Include closed application issues incorporated into this release.
5. Resolve cross-repository identifiers, including USER, DBA, CLAM and other prefixes, to their owning repositories.
6. Include a closed cross-repository issue only when its commits were incorporated into this application release.
7. Describe a cross-repository issue in terms of its effect on this application.
8. Deduplicate identifiers that occur in several repositories.
9. Exclude every issue carrying the internal-only label.
10. Do not infer that every associated-repository commit is part of the application merely because it falls within the date range.
11. Flag ambiguous identifiers or inclusion decisions for review rather than silently guessing.
12. Do not include commits without an issue identifier as release-note entries. Report them separately for review if they appear user-visible.

Write each included issue as a level-three heading:

### [<ISSUE TITLE>](<CANONICAL ISSUE URL>)

<ONE SHORT USER-FACING PARAGRAPH>

Writing rules:

- Use the issue's first paragraph as source material where suitable, but verify it against the completed issue and relevant commits.
- Use terse third-person present tense.
- Prefer verbs such as Allows, Shows, Prevents and Improves.
- For defects, normally begin: Fixes a bug where...
- Avoid You can now, implementation detail, estimates, acceptance criteria and development history.
- Describe observable behaviour or meaningful operational protection.
- Do not claim behaviour unsupported by the issue or commits.
- Keep one issue to one paragraph.
- Keep release metadata out of `<RELEASE-NOTES-PATH>`; it is a public user-facing document.

Create or replace `<RELEASE-STATE-PATH>` in the application repository using:

```yaml
release: release-<GLOBAL-RELEASE-NUMBER>-<YYYY-MM-DD>
repositories:
  application: <PROPOSED-RELEASE-TAG>
  app-user: <INCORPORATED-COMMIT-SHA>
  database-access: <INCORPORATED-COMMIT-SHA>
  webapp-core: <INCORPORATED-COMMIT-SHA>
  configuration: <INCORPORATED-COMMIT-SHA>
```

Record the precise associated-repository revisions incorporated into the application, not simply whichever commits happen to be newest. Do not put release-state metadata in an HTML comment or any other part of `<RELEASE-NOTES-PATH>`.

Before writing:

1. Show the proposed issue list.
2. Show excluded internal-only issues.
3. Show ambiguous references and apparently user-visible untracked commits.
4. Ask for confirmation if any inclusion decision would materially change the release notes.

After confirmation, update `<RELEASE-NOTES-PATH>` and `<RELEASE-STATE-PATH>` in the application repository. Do not create a Git tag, deploy the application, close issues or notify users.
```

## Blagger values

For Blagger, substitute:

```text
<APPLICATION-NAME> = Blagger
<OWNER>/<APPLICATION-REPOSITORY> = decani/blagger
<APPLICATION-PREFIX> = BLG
<RELEASE-NOTES-PATH> = blagger-web/src/main/resources/documents/release-notes.md
<RELEASE-STATE-PATH> = blagger-web/src/main/resources/documents/release-state.yml
```

The application prefix is used to identify Blagger issues; it is not included in the repository-scoped release tag.

The global release number remains provisional until the candidate is built, deployed, smoke-tested, tagged and users are notified according to the release guide.
