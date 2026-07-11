/**
 * Pure parsing/validation for scan-feedback submissions.
 * Kept separate from the route so it is unit-testable without a database.
 *
 * Accepts both snake_case (what the iOS client actually sends, because its
 * JSONEncoder uses .convertToSnakeCase) and camelCase (convenient for curl).
 */

const UUID_RE =
  /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

export interface ScanFeedback {
  submissionId: string;
  deviceId: string | null;
  cardId: string;
  barcodeType: string | null;
  worked: boolean;
  note: string | null;
}

export type ScanFeedbackParse =
  | { ok: true; value: ScanFeedback }
  | { ok: false; error: string };

function readString(b: Record<string, unknown>, ...keys: string[]): string | null {
  for (const k of keys) {
    const v = b[k];
    if (typeof v === 'string' && v.trim().length > 0) return v.trim();
  }
  return null;
}

function readBool(b: Record<string, unknown>, ...keys: string[]): boolean | null {
  for (const k of keys) {
    if (typeof b[k] === 'boolean') return b[k] as boolean;
  }
  return null;
}

export function parseScanFeedback(body: unknown): ScanFeedbackParse {
  if (typeof body !== 'object' || body === null) {
    return { ok: false, error: 'Invalid body' };
  }
  const b = body as Record<string, unknown>;

  const submissionId = readString(b, 'submission_id', 'submissionId');
  if (!submissionId || !UUID_RE.test(submissionId)) {
    return { ok: false, error: 'submission_id (uuid) is required' };
  }

  const cardId = readString(b, 'card_id', 'cardId');
  if (!cardId) {
    return { ok: false, error: 'card_id is required' };
  }

  const worked = readBool(b, 'worked');
  if (worked === null) {
    return { ok: false, error: 'worked (boolean) is required' };
  }

  const note = readString(b, 'note');
  return {
    ok: true,
    value: {
      submissionId,
      deviceId: readString(b, 'device_id', 'deviceId'),
      cardId,
      barcodeType: readString(b, 'barcode_type', 'barcodeType'),
      worked,
      note: note ? note.slice(0, 2000) : null,
    },
  };
}
