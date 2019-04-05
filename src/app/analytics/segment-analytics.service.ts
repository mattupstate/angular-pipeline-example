export class SegmentAnalytics {
  constructor(private analytics: any, private localeId: string, debug = false) {
    if (debug) {
      this.analytics.debug();
    }
  }

  private applyStaticProperties(properties: any) {
    return {
      localeId: this.localeId,
      ...properties
    };
  }

  page(name: string, category?: string, properties = {}) {
    this.analytics.page(category, name, this.applyStaticProperties(properties));
  }

  track(event: string, properties = {}) {
    this.analytics.track(event, this.applyStaticProperties(properties));
  }

  identify(userId: string, properties = {}) {
    this.analytics.identify(userId, this.applyStaticProperties(properties));
  }
}
