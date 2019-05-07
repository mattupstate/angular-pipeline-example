import { BuildInfo } from './build-info';

export const environment = {
  production: true,
  segment: {
    writeKey: '6hFmeOfdLCTWqyoU6JBEJ01ytIiyPPgm',
    options: {
      integrations: {
        All: true
      }
    }
  },
  sentry: {
    enabled: true,
    environment: 'production',
    release: BuildInfo.gitCommitHash,
    dsn: 'https://39c2faf6aaa44b319d790e1f2f77886b@sentry.io/1449637'
  }
};
