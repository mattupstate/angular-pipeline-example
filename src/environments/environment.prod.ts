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
  rollbar: {
    enabled: true,
    accessToken: 'bcbcced242ca43a9b9e8c3cbce7f32d4',
    captureUncaught: true,
    captureUnhandledRejections: true,
    environment: 'production',
    codeVersion: BuildInfo.gitCommitHash
  },
  sentry: {
    enabled: true,
    environment: 'production',
    release: BuildInfo.gitCommitHash,
    dsn: 'https://39c2faf6aaa44b319d790e1f2f77886b@sentry.io/1449637'
  }
};
