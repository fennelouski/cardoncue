import { parseScanFeedback } from '../lib/scanFeedback';

const VALID_UUID = '11111111-2222-3333-4444-555555555555';

describe('parseScanFeedback', () => {
  it('accepts a valid snake_case body (iOS client shape) and trims the note', () => {
    const res = parseScanFeedback({
      submission_id: VALID_UUID,
      device_id: 'device-abc',
      card_id: 'card-123',
      barcode_type: 'qr',
      worked: false,
      note: '  scanner rejected it  ',
    });
    expect(res.ok).toBe(true);
    if (res.ok) {
      expect(res.value).toEqual({
        submissionId: VALID_UUID,
        deviceId: 'device-abc',
        cardId: 'card-123',
        barcodeType: 'qr',
        worked: false,
        note: 'scanner rejected it',
      });
    }
  });

  it('also accepts camelCase with no note (manual curl)', () => {
    const res = parseScanFeedback({ submissionId: VALID_UUID, cardId: 'c1', worked: true });
    expect(res.ok).toBe(true);
    if (res.ok) expect(res.value.note).toBeNull();
  });

  it('rejects a missing or malformed submission_id', () => {
    expect(parseScanFeedback({ card_id: 'c1', worked: true }).ok).toBe(false);
    expect(
      parseScanFeedback({ submission_id: 'not-a-uuid', card_id: 'c1', worked: true }).ok
    ).toBe(false);
  });

  it('rejects a missing card_id', () => {
    expect(parseScanFeedback({ submission_id: VALID_UUID, worked: true }).ok).toBe(false);
  });

  it('rejects a missing or non-boolean worked', () => {
    expect(parseScanFeedback({ submission_id: VALID_UUID, card_id: 'c1' }).ok).toBe(false);
    expect(
      parseScanFeedback({ submission_id: VALID_UUID, card_id: 'c1', worked: 'yes' }).ok
    ).toBe(false);
  });

  it('rejects a non-object body', () => {
    expect(parseScanFeedback(null).ok).toBe(false);
    expect(parseScanFeedback('nope').ok).toBe(false);
  });
});
