import assert from 'node:assert/strict';
import test from 'node:test';

import {
  appStoreCalendarDateAt,
  effectivePriceAt,
  effectivePriceRowsAt,
} from './asc_price_schedule.mjs';

function price(id, startDate, territory = 'USA') {
  return {
    id,
    attributes: { startDate },
    relationships: { territory: { data: { id: territory } } },
  };
}

test('a null startDate is effective immediately', () => {
  const immediate = price('immediate', null);
  assert.equal(
    effectivePriceAt(
      [immediate],
      'USA',
      new Date('2026-08-01T00:00:00.000Z'),
    ),
    immediate,
  );
});

test('a Pacific-today row is not effective before Pacific midnight', () => {
  const scheduled = price('scheduled', '2026-08-30');
  const justBeforePacificMidnight = new Date('2026-08-30T06:59:59.999Z');

  assert.equal(
    appStoreCalendarDateAt(justBeforePacificMidnight),
    '2026-08-29',
  );
  assert.equal(
    effectivePriceAt([scheduled], 'USA', justBeforePacificMidnight),
    undefined,
  );
});

test('a Pacific-today row becomes effective at Pacific midnight', () => {
  const scheduled = price('scheduled', '2026-08-30');
  const atPacificMidnight = new Date('2026-08-30T07:00:00.000Z');

  assert.equal(appStoreCalendarDateAt(atPacificMidnight), '2026-08-30');
  assert.equal(
    effectivePriceAt([scheduled], 'USA', atPacificMidnight),
    scheduled,
  );
});

test('effective rows sort null first and dated rows chronologically', () => {
  const rows = [
    price('tomorrow', '2026-08-31'),
    price('today-second', '2026-08-30'),
    price('baseline', null),
    price('yesterday', '2026-08-29'),
    price('other-territory', '2026-08-30', 'CAN'),
    price('today-first', '2026-08-30'),
  ];
  const duringPacificToday = new Date('2026-08-30T18:00:00.000Z');

  const effectiveRows = effectivePriceRowsAt(
    rows,
    'USA',
    duringPacificToday,
  );
  assert.deepEqual(
    effectiveRows.map((row) => row.id),
    ['baseline', 'yesterday', 'today-second', 'today-first'],
  );
  assert.equal(
    effectivePriceAt(rows, 'USA', duringPacificToday)?.id,
    'today-first',
  );
});
