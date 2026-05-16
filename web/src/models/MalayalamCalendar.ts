// ─────────────────────────────────────────────────────────────────────────────
// Malayalam Calendar Domain Types
// Ported from MalayalamCalendarTypes.swift
// ─────────────────────────────────────────────────────────────────────────────

// ---------------------------------------------------------------------------
// Nakshatra (27 lunar mansions)
// ---------------------------------------------------------------------------
export const NAKSHATRAS = [
  { id: 0,  english: 'Aswathi',     malayalam: 'അശ്വതി'      },
  { id: 1,  english: 'Bharani',     malayalam: 'ഭരണി'        },
  { id: 2,  english: 'Karthika',    malayalam: 'കാർത്തിക'    },
  { id: 3,  english: 'Rohini',      malayalam: 'രോഹിണി'      },
  { id: 4,  english: 'Makayiram',   malayalam: 'മകയിരം'      },
  { id: 5,  english: 'Thiruvathira',malayalam: 'തിരുവാതിര'   },
  { id: 6,  english: 'Punartham',   malayalam: 'പുണർതം'      },
  { id: 7,  english: 'Pooyam',      malayalam: 'പൂയം'        },
  { id: 8,  english: 'Aayilyam',    malayalam: 'ആയില്യം'     },
  { id: 9,  english: 'Makam',       malayalam: 'മകം'         },
  { id: 10, english: 'Pooram',      malayalam: 'പൂരം'        },
  { id: 11, english: 'Uthram',      malayalam: 'ഉത്രം'       },
  { id: 12, english: 'Atham',       malayalam: 'അത്തം'       },
  { id: 13, english: 'Chithira',    malayalam: 'ചിത്തിര'     },
  { id: 14, english: 'Chothi',      malayalam: 'ചോതി'        },
  { id: 15, english: 'Vishakam',    malayalam: 'വിശാഖം'      },
  { id: 16, english: 'Anizham',     malayalam: 'അനിഴം'       },
  { id: 17, english: 'Thrikketta',  malayalam: 'തൃക്കേട്ട'   },
  { id: 18, english: 'Moolam',      malayalam: 'മൂലം'        },
  { id: 19, english: 'Pooradam',    malayalam: 'പൂരാടം'      },
  { id: 20, english: 'Uthradam',    malayalam: 'ഉത്രാടം'     },
  { id: 21, english: 'Thiruvonam',  malayalam: 'തിരുവോണം'    },
  { id: 22, english: 'Avittam',     malayalam: 'അവിട്ടം'     },
  { id: 23, english: 'Chathayam',   malayalam: 'ചതയം'        },
  { id: 24, english: 'Pooruruttathi',malayalam: 'പൂരുരുട്ടാതി'},
  { id: 25, english: 'Uthirattathi',malayalam: 'ഉത്തൃട്ടാതി' },
  { id: 26, english: 'Revathi',     malayalam: 'രേവതി'       },
] as const

export type NakshatraId = 0|1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26
export const NAKSHATRA_SPAN_DEG = 360 / 27  // 13.3333...°

export function nakshatraFromLongitude(siderealDeg: number): NakshatraId {
  const norm = ((siderealDeg % 360) + 360) % 360
  return Math.min(Math.floor(norm / NAKSHATRA_SPAN_DEG), 26) as NakshatraId
}

export function nakshatraName(id: NakshatraId, lang: 'english' | 'malayalam' = 'english') {
  return NAKSHATRAS[id][lang]
}

// ---------------------------------------------------------------------------
// Malayalam Month (12 months, Chingam = 0)
// ---------------------------------------------------------------------------
export const MALAYALAM_MONTHS = [
  { id: 0,  english: 'Chingam',    malayalam: 'ചിങ്ങം'     },
  { id: 1,  english: 'Kanni',      malayalam: 'കന്നി'       },
  { id: 2,  english: 'Thulam',     malayalam: 'തുലാം'       },
  { id: 3,  english: 'Vrischikam', malayalam: 'വൃശ്ചികം'   },
  { id: 4,  english: 'Dhanu',      malayalam: 'ധനു'         },
  { id: 5,  english: 'Makaram',    malayalam: 'മകരം'        },
  { id: 6,  english: 'Kumbham',    malayalam: 'കുംഭം'       },
  { id: 7,  english: 'Meenam',     malayalam: 'മീനം'        },
  { id: 8,  english: 'Medam',      malayalam: 'മേടം'        },
  { id: 9,  english: 'Edavam',     malayalam: 'ഇടവം'        },
  { id: 10, english: 'Mithunam',   malayalam: 'മിഥുനം'      },
  { id: 11, english: 'Karkidakam', malayalam: 'കർക്കടകം'   },
] as const

export type MalayalamMonthId = 0|1|2|3|4|5|6|7|8|9|10|11

export function monthName(id: MalayalamMonthId, lang: 'english' | 'malayalam' = 'english') {
  return MALAYALAM_MONTHS[id][lang]
}

// ---------------------------------------------------------------------------
// Tithi (30 lunar days)
// ---------------------------------------------------------------------------
export const TITHIS = [
  { id: 0,  english: 'Prathama',    paksha: 'shukla' },
  { id: 1,  english: 'Dvitiya',     paksha: 'shukla' },
  { id: 2,  english: 'Tritiya',     paksha: 'shukla' },
  { id: 3,  english: 'Chaturthi',   paksha: 'shukla' },
  { id: 4,  english: 'Panchami',    paksha: 'shukla' },
  { id: 5,  english: 'Shashti',     paksha: 'shukla' },
  { id: 6,  english: 'Saptami',     paksha: 'shukla' },
  { id: 7,  english: 'Ashtami',     paksha: 'shukla' },
  { id: 8,  english: 'Navami',      paksha: 'shukla' },
  { id: 9,  english: 'Dashami',     paksha: 'shukla' },
  { id: 10, english: 'Ekadashi',    paksha: 'shukla' },
  { id: 11, english: 'Dvadashi',    paksha: 'shukla' },
  { id: 12, english: 'Trayodashi',  paksha: 'shukla' },
  { id: 13, english: 'Chaturdashi', paksha: 'shukla' },
  { id: 14, english: 'Pournami',    paksha: 'shukla' },
  { id: 15, english: 'Prathama',    paksha: 'krishna'},
  { id: 16, english: 'Dvitiya',     paksha: 'krishna'},
  { id: 17, english: 'Tritiya',     paksha: 'krishna'},
  { id: 18, english: 'Chaturthi',   paksha: 'krishna'},
  { id: 19, english: 'Panchami',    paksha: 'krishna'},
  { id: 20, english: 'Shashti',     paksha: 'krishna'},
  { id: 21, english: 'Saptami',     paksha: 'krishna'},
  { id: 22, english: 'Ashtami',     paksha: 'krishna'},
  { id: 23, english: 'Navami',      paksha: 'krishna'},
  { id: 24, english: 'Dashami',     paksha: 'krishna'},
  { id: 25, english: 'Ekadashi',    paksha: 'krishna'},
  { id: 26, english: 'Dvadashi',    paksha: 'krishna'},
  { id: 27, english: 'Trayodashi',  paksha: 'krishna'},
  { id: 28, english: 'Chaturdashi', paksha: 'krishna'},
  { id: 29, english: 'Amavasya',    paksha: 'krishna'},
] as const

export type TithiId = 0|1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29
export type Paksha = 'shukla' | 'krishna'
export const TITHI_SPAN_DEG = 12

export function tithiFromElongation(elongation: number): TithiId {
  const norm = ((elongation % 360) + 360) % 360
  return Math.min(Math.floor(norm / TITHI_SPAN_DEG), 29) as TithiId
}

export function pakshaShortName(paksha: Paksha): string {
  return paksha === 'shukla' ? 'S' : 'K'
}

// ---------------------------------------------------------------------------
// Weekday (1 = Sunday, matching Kerala convention)
// ---------------------------------------------------------------------------
export function weekdayFromDate(date: Date): number {
  return date.getDay() + 1  // getDay() returns 0=Sun; add 1 → 1=Sun..7=Sat
}
