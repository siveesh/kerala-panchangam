// ─────────────────────────────────────────────────────────────────────────────
// FamilyStore — IndexedDB-backed profile persistence via the `idb` library
// ─────────────────────────────────────────────────────────────────────────────

import { openDB, type IDBPDatabase } from 'idb'
import type { PersonProfile } from '../models/FamilyTypes'

const DB_NAME = 'panchangam'
const STORE   = 'profiles'
const VERSION = 1

async function db(): Promise<IDBPDatabase> {
  return openDB(DB_NAME, VERSION, {
    upgrade(db) {
      if (!db.objectStoreNames.contains(STORE)) {
        db.createObjectStore(STORE, { keyPath: 'id' })
      }
    },
  })
}

export async function loadProfiles(): Promise<PersonProfile[]> {
  const database = await db()
  return database.getAll(STORE)
}

export async function saveProfile(profile: PersonProfile): Promise<void> {
  const database = await db()
  await database.put(STORE, profile)
}

export async function deleteProfile(id: string): Promise<void> {
  const database = await db()
  await database.delete(STORE, id)
}

export async function replaceAllProfiles(profiles: PersonProfile[]): Promise<void> {
  const database = await db()
  const tx = database.transaction(STORE, 'readwrite')
  await tx.store.clear()
  for (const p of profiles) await tx.store.put(p)
  await tx.done
}

// ---------------------------------------------------------------------------
// Backup / restore (plain JSON, unencrypted — same as macOS app export)
// ---------------------------------------------------------------------------
export function exportBackupJSON(profiles: PersonProfile[]): string {
  return JSON.stringify(profiles, null, 2)
}

export function importBackupJSON(json: string): PersonProfile[] {
  const parsed = JSON.parse(json)
  if (!Array.isArray(parsed)) throw new Error('Invalid backup: expected array')
  return parsed as PersonProfile[]
}
