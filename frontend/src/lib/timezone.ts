// Timezone conversion helpers with no external dependency. TimeCreated values
// coming from the backend are naive wall-clock strings (a trailing Z/offset,
// if present, is stripped) that are assumed to represent a time in
// `sourceTz`. Display converts that into `targetTz`; date-range filters do
// the reverse so the bound sent to the backend is comparable to the raw
// TimeCreated string.

export function getBrowserTimeZone(): string {
  return Intl.DateTimeFormat().resolvedOptions().timeZone
}

export function listTimeZones(): string[] {
  try {
    const supportedValuesOf = (Intl as unknown as { supportedValuesOf?: (key: string) => string[] }).supportedValuesOf
    if (supportedValuesOf) {
      const zones = supportedValuesOf('timeZone')
      return ['UTC', ...zones.filter((z) => z !== 'UTC')]
    }
  } catch {
    // fall through
  }
  const browserTz = getBrowserTimeZone()
  return browserTz === 'UTC' ? ['UTC'] : ['UTC', browserTz]
}

function getOffsetMinutes(zone: string, date: Date): number {
  const zoned = new Date(date.toLocaleString('en-US', { timeZone: zone }))
  const utc = new Date(date.toLocaleString('en-US', { timeZone: 'UTC' }))
  return (zoned.getTime() - utc.getTime()) / 60000
}

/** Reinterprets a naive "YYYY-MM-DDTHH:mm:ss[.sss]" string as wall-clock time in `zone` and returns the real UTC instant. */
export function zonedWallClockToUtcInstant(naiveStr: string, zone: string): Date | null {
  const m = naiveStr.match(/^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?/)
  if (!m) return null
  const [, y, mo, d, h, mi, s, frac] = m
  const ms = frac ? Math.round(Number(`0.${frac}`) * 1000) : 0
  const utcGuess = new Date(Date.UTC(Number(y), Number(mo) - 1, Number(d), Number(h), Number(mi), Number(s), ms))

  const offset = getOffsetMinutes(zone, utcGuess)
  let instant = new Date(utcGuess.getTime() - offset * 60000)
  const offset2 = getOffsetMinutes(zone, instant)
  if (offset2 !== offset) {
    instant = new Date(utcGuess.getTime() - offset2 * 60000)
  }
  return instant
}

/** Formats a real UTC instant as a naive "YYYY-MM-DDTHH:mm:ss.SSS" string representing wall-clock time in `zone`. */
export function utcInstantToZonedNaiveString(date: Date, zone: string): string {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: zone,
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit',
    hour12: false,
  }).formatToParts(date)
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? '00'
  const ms = String(date.getMilliseconds()).padStart(3, '0')
  const hour = get('hour') === '24' ? '00' : get('hour')
  return `${get('year')}-${get('month')}-${get('day')}T${hour}:${get('minute')}:${get('second')}.${ms}`
}

function stripTzMarker(s: string): string {
  if (s.endsWith('Z')) return s.slice(0, -1)
  const m = s.match(/^(.*\d{2}:\d{2}:\d{2}(?:\.\d+)?)([+-]\d{2}:\d{2})$/)
  return m ? m[1] : s
}

/** Converts a raw TimeCreated value (naive wall-clock in `sourceTz`) into a display string in `targetTz`. */
export function formatTimeCreated(raw: string, sourceTz: string, targetTz: string): string {
  if (!raw) return ''
  const instant = zonedWallClockToUtcInstant(stripTzMarker(raw), sourceTz)
  if (!instant) return raw
  return utcInstantToZonedNaiveString(instant, targetTz).replace('T', ' ').slice(0, 19)
}

/** Converts a <input type="datetime-local"> value (wall-clock in `targetTz`) into the naive-in-`sourceTz` string the backend compares TimeCreated against. */
export function targetInputToSourceNaive(inputValue: string, sourceTz: string, targetTz: string): string {
  if (!inputValue) return ''
  const instant = zonedWallClockToUtcInstant(inputValue, targetTz)
  if (!instant) return ''
  return utcInstantToZonedNaiveString(instant, sourceTz)
}
