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
    accessToken: 'bcbcced242ca43a9b9e8c3cbce7f32d4',
    environment: 'production',
    captureUncaught: true,
    captureUnhandledRejections: true
  }
};
