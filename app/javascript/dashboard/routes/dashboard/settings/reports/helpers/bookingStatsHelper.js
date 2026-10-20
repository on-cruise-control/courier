const isTwilioWhatsapp = inbox =>
  inbox.channel_type === 'Channel::TwilioSms' && inbox.medium === 'whatsapp';

// Channels shown on the booking / handoff reports, matching the dealership stats platforms
export const BOOKING_PLATFORMS = [
  {
    key: 'website',
    labelKey: 'WEBSITE',
    hasInbox: inbox => inbox.channel_type === 'Channel::WebWidget',
  },
  {
    key: 'facebook',
    labelKey: 'FACEBOOK',
    hasInbox: inbox => inbox.channel_type === 'Channel::FacebookPage',
  },
  {
    key: 'whatsapp',
    labelKey: 'WHATSAPP',
    hasInbox: inbox =>
      inbox.channel_type === 'Channel::Whatsapp' || isTwilioWhatsapp(inbox),
  },
  {
    key: 'sms',
    labelKey: 'SMS',
    hasInbox: inbox =>
      inbox.channel_type === 'Channel::Sms' ||
      (inbox.channel_type === 'Channel::TwilioSms' && !isTwilioWhatsapp(inbox)),
  },
  {
    key: 'email',
    labelKey: 'EMAIL',
    hasInbox: inbox => inbox.channel_type === 'Channel::Email',
  },
  {
    key: 'instagram',
    labelKey: 'INSTAGRAM',
    hasInbox: inbox => inbox.channel_type === 'Channel::Instagram',
  },
];

export const buildBookingReportKeys = (type, platform) => ({
  LINKS_SENT: `${type}_${platform}_links_sent`,
  FORMS_COMPLETED: `${type}_${platform}_forms_completed`,
});
