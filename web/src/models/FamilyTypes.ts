// ─────────────────────────────────────────────────────────────────────────────
// Family Profile Types
// Ported from FamilyTypes.swift
// ─────────────────────────────────────────────────────────────────────────────

import type { NakshatraId, MalayalamMonthId, TithiId, Paksha } from './MalayalamCalendar'

export type FieldEntryMode = 'unset' | 'calculated' | 'manual' | 'confirmed'

export interface BirthDetails {
  dateOfBirth: string          // ISO date string "YYYY-MM-DD"
  birthTimeISO?: string        // ISO datetime string (local) when exact time known
  birthLocationName?: string
  birthLatitude?: number
  birthLongitude?: number
  birthTimeZoneId?: string
  birthNakshatra?: NakshatraId
  birthTithi?: TithiId
  birthPaksha?: Paksha
  birthMalayalamMonth?: MalayalamMonthId
  birthMalayalamDay?: number
  birthKollavarshamYear?: number
  nakshatraEntry: FieldEntryMode
  tithiEntry: FieldEntryMode
}

export interface DeathDetails {
  dateOfDeath: string          // ISO date string "YYYY-MM-DD"
  deathTimeISO?: string
  deathLocationName?: string
  deathLatitude?: number
  deathLongitude?: number
  deathTimeZoneId?: string
  deathNakshatra?: NakshatraId
  deathTithi?: TithiId
  deathPaksha?: Paksha
  deathMalayalamMonth?: MalayalamMonthId
  deathMalayalamDay?: number
  deathKollavarshamYear?: number
  nakshatraEntry: FieldEntryMode
  tithiEntry: FieldEntryMode
}

export interface FamilyReminderPreferences {
  enableBirthdayReminder: boolean
  birthdayReminderHour: number          // 0–23, default 7
  birthdayReminderMinute: number        // default 0
  birthdayNakshatraPolicy: DuplicateNakshatraPolicy
  enableShraddhamReminder: boolean
  shraddhamReminderHour: number
  shraddhamReminderMinute: number
  shraddhamMode: ShraddhamObservanceMode
}

export const DEFAULT_REMINDER_PREFS: FamilyReminderPreferences = {
  enableBirthdayReminder: true,
  birthdayReminderHour: 7,
  birthdayReminderMinute: 0,
  birthdayNakshatraPolicy: 'alwaysSecond',
  enableShraddhamReminder: true,
  shraddhamReminderHour: 6,
  shraddhamReminderMinute: 0,
  shraddhamMode: 'nakshatraOnly',
}

export interface PersonProfile {
  id: string                          // UUID string
  fullName: string
  nickname: string
  relationshipTag: string             // "Father", "Spouse", etc.
  notes: string
  birthDetails?: BirthDetails
  deathDetails?: DeathDetails         // undefined = living
  reminderPreferences: FamilyReminderPreferences
  isArchived: boolean
  createdAt: string                   // ISO datetime
  updatedAt: string
}

// Derived helpers
export function isDeceased(p: PersonProfile): boolean {
  return p.deathDetails !== undefined
}
export function displayName(p: PersonProfile): string {
  return p.nickname.trim() !== '' ? p.nickname : p.fullName
}

// ---------------------------------------------------------------------------
// Nakshatra duplicate policy (mirrors Swift DuplicateNakshatraPolicy)
// ---------------------------------------------------------------------------
export type DuplicateNakshatraPolicy =
  | 'alwaysFirst'
  | 'alwaysSecond'
  | 'longestDuration'
  | 'preferSecondUnlessShort'

// ---------------------------------------------------------------------------
// Śrāddham observance mode
// ---------------------------------------------------------------------------
export type ShraddhamObservanceMode =
  | 'nakshatraOnly'
  | 'nakshatraPreferred'
  | 'tithiPreferred'
  | 'tithiAndNakshatra'

// ---------------------------------------------------------------------------
// ShraddhamDate — output of ShraddhamDateFinder
// ---------------------------------------------------------------------------
export interface ShraddhamDate {
  id: string
  personId: string
  personName: string
  gregorianDate: Date
  tithi: TithiId
  paksha: Paksha
  malayalamDateLabel: string
  selectionRuleDescription: string
}

// ---------------------------------------------------------------------------
// CalendarEvent (for .ics export)
// ---------------------------------------------------------------------------
export interface FamilyCalendarEvent {
  title: string
  startDate: Date
  endDate: Date
  notes?: string
  personId: string
}
