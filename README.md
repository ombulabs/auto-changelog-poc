# Auto Changelog

Example workflow to add to target project:

```yml
name: Auto Changelog

on:
  pull_request:
    types: [labeled]

permissions:
  pull-requests: write
  contents: write

jobs:
  test-auto-changelog:
    if: github.event.label.name == '[label]'
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
          submodules: true

      - name: Run Auto Changelog Action
        uses: ./.github/actions/auto-changelog
        with:
          openai_api_key: ${{ secrets.OPENAI_API_KEY }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
          changelog_path: "CHANGELOG.md"
          mode: [comment | commit]
```
