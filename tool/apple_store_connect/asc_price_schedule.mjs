/**
 * Pure helpers for interpreting App Store Connect subscription price rows.
 *
 * App Store Connect exposes `startDate` as a calendar date, not as a UTC
 * timestamp. Treating that value as UTC can select a scheduled row several
 * hours early while it is still the previous day in Apple's Pacific calendar.
 */

export const APP_STORE_CALENDAR_TIME_ZONE = 'America/Los_Angeles';

const appStoreDateFormatter = new Intl.DateTimeFormat('en-US', {
  calendar: 'gregory',
  numberingSystem: 'latn',
  timeZone: APP_STORE_CALENDAR_TIME_ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

function assertValidInstant(instant) {
  const date = instant instanceof Date ? instant : new Date(instant);
  if (Number.isNaN(date.getTime())) {
    throw new TypeError(`Invalid clock instant: ${String(instant)}`);
  }
  return date;
}

function startDateOf(price) {
  const startDate = price?.attributes?.startDate;
  if (startDate == null) return null;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(startDate)) {
    throw new TypeError(`Invalid App Store Connect startDate: ${startDate}`);
  }
  return startDate;
}

/** Return YYYY-MM-DD for a fixed instant in Apple's Pacific calendar. */
export function appStoreCalendarDateAt(instant) {
  const parts = Object.fromEntries(
    appStoreDateFormatter
      .formatToParts(assertValidInstant(instant))
      .filter((part) => part.type !== 'literal')
      .map((part) => [part.type, part.value]),
  );
  return `${parts.year}-${parts.month}-${parts.day}`;
}

/**
 * Return effective rows oldest-to-newest for one territory at a fixed instant.
 * A null startDate is an immediately effective baseline and sorts before every
 * dated row. Equal-date rows retain their source order.
 */
export function effectivePriceRowsAt(prices, territory, instant) {
  if (!Array.isArray(prices)) {
    throw new TypeError('prices must be an array');
  }

  const appleToday = appStoreCalendarDateAt(instant);
  return prices
    .map((price, sourceIndex) => ({
      price,
      sourceIndex,
      startDate: startDateOf(price),
    }))
    .filter(({ price, startDate }) => {
      if (price?.relationships?.territory?.data?.id !== territory) return false;
      return startDate == null || startDate <= appleToday;
    })
    .sort((left, right) => {
      if (left.startDate == null && right.startDate != null) return -1;
      if (left.startDate != null && right.startDate == null) return 1;
      const byDate = (left.startDate ?? '').localeCompare(
        right.startDate ?? '',
      );
      return byDate || left.sourceIndex - right.sourceIndex;
    })
    .map(({ price }) => price);
}

/** Select the latest effective row for one territory at a fixed instant. */
export function effectivePriceAt(prices, territory, instant) {
  return effectivePriceRowsAt(prices, territory, instant).at(-1);
}
