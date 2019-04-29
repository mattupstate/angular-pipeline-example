export class SegmentAnalytics {
  constructor(private analytics: any, private staticProperties: object, debug = false) {
    if (debug) {
      this.analytics.debug();
    }
  }

  private applyStaticProperties(properties: object) {
    return {
      ...this.staticProperties,
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
