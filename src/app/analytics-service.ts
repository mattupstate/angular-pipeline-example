export abstract class AnalyticsService {
  abstract identify(userId: string, attributes: any): void;
  abstract page(path: string): void;
  abstract track(event: string, attributes: any): void;
}
