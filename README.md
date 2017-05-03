# Test Coverage Report

[![Code Climate][badge]][repo]

[repo]: https://codeclimate.com/github/codeclimate/test-coverage-report
[badge]: https://codeclimate.com/github/codeclimate/test-coverage-report/badges/gpa.svg

Reports on test coverage for added lines of code within a specified timeframe.
Uses GitHub and Code Climate APIs.

## Usage

You can the fetch latest version of the reporter by pulling from Docker Hub:

```shell
docker pull codeclimate/test-coverage-report
```

To use this reporting tool, you must have a [GitHub access token][] and a [Code
Climate access token][] available.

[GitHub access token]: https://github.com/settings/tokens
[Code Climate access token]: https://codeclimate.com/profile/tokens

Both access tokens must have access to the respective repositories in order to
collect commit and test coverage data. You may run the report against an
alternate timeframe (defaults to the past 7 days) by specifying the number of
days to include.

```shell
docker run -it \
  --env CC_ACCESS_TOKEN="<Code Climate Access Token>" \
  --env GITHUB_ACCESS_TOKEN="<GitHub Access Token>" \
  codeclimate/test-coverage-report \
  <owner/repo> [days=7]
```
