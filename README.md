# Test Coverage Report

Reports on test coverage for added lines of code within a specified timeframe.
Uses GitHub and Code Climate APIs.

```
docker run -it \
  --env CC_ACCESS_TOKEN="<Code Climate Access Token>" \
  --env GITHUB_ACCESS_TOKEN="<GitHub Access Token>" \
  codeclimate/test-coverage-report \
  <owner/repo> [days=7]
```
