import { getTime } from 'dashboard/routes/dashboard/settings/inbox/helpers/businessHour';

const MINUTES_IN_DAY = 24 * 60;
const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

const toMinutes = time => {
  const [hour, minute] = time.split(':').map(Number);
  return hour * 60 + minute;
};

// Returns the closing time (e.g. "05:00 PM") of the service window that is open right now, or null when outside service hours.
// A 00:00 close means the window runs until the end of the day.
export const getServiceWindowClose = (serviceHours, now = new Date()) => {
  if (!serviceHours?.timezone) return null;

  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-US', {
      timeZone: serviceHours.timezone,
      weekday: 'short',
      hour: 'numeric',
      minute: 'numeric',
      hourCycle: 'h23',
    })
      .formatToParts(now)
      .map(({ type, value }) => [type, value])
  );
  const slot = serviceHours.schedule?.[WEEKDAYS.indexOf(parts.weekday)];
  if (!slot) return null;

  const current = Number(parts.hour) * 60 + Number(parts.minute);
  const closeMinutes = toMinutes(slot.close) || MINUTES_IN_DAY;
  if (current < toMinutes(slot.open) || current >= closeMinutes) return null;

  return getTime(Math.floor(closeMinutes / 60) % 24, closeMinutes % 60);
};
