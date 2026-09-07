## Change and affected environments

## Security, cost and data impact
- [ ] No secrets, state or plans committed
- [ ] Dev/prod account and OIDC boundaries preserved
- [ ] Data deletion/replacement and DNS changes explicitly identified
- [ ] SQL compatibility, migration and rollback considered
- [ ] Monthly cost change reviewed
- [ ] Scanner exceptions (if any) justified and time-bounded where supported

## Verification
- [ ] `make check` / all required GitHub checks
- [ ] Mock tests updated; no AWS credentials used by PR jobs
- [ ] Restore/rollback plan documented for stateful changes

## Rollout / rollback
