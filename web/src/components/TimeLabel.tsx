// Small utility component: formats a Date as a local time string (HH:MM AM/PM)
import type { GeoLocation } from '../models/CoreTypes'

interface Props { date: Date; location: GeoLocation; className?: string }

export function TimeLabel({ date, location, className }: Props) {
  const str = date.toLocaleTimeString('en-IN', {
    timeZone: location.timeZoneId,
    hour: '2-digit', minute: '2-digit', hour12: true,
  })
  return <span className={className}>{str}</span>
}
