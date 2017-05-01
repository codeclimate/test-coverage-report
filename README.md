# Test Coverage Report

[![Code Climate](https://codeclimate.com/github/codeclimate/test-coverage-report/badges/gpa.svg)](https://codeclimate.com/github/codeclimate/test-coverage-report)

Reports on test coverage for added lines of code within a specified timeframe.
Uses GitHub and Code Climate APIs.

```shell
docker run -it \
  --env CC_ACCESS_TOKEN="<Code Climate Access Token>" \
  --env GITHUB_ACCESS_TOKEN="<GitHub Access Token>" \
  codeclimate/test-coverage-report \
  <owner/repo> [days=7]
```
