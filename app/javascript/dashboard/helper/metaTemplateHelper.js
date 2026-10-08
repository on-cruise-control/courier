export function collectTemplateTexts(content, category) {
  const safeContent = content || {};

  if (category === 'text') return [safeContent.body];
  if (category === 'media') return [safeContent.caption];
  if (category === 'quick_reply') {
    return [
      safeContent.body,
      ...(safeContent.items || []).map(item => item.title),
    ];
  }
  if (category === 'call_to_action') {
    const item = (safeContent.items || [])[0] || {};
    return [item.text, ...(item.buttons || []).map(button => button.title)];
  }
  if (category === 'card') {
    return (safeContent.items || []).flatMap(item => [
      item.title,
      item.description,
      ...(item.actions || []).map(action => action.text),
    ]);
  }
  return [];
}

// Users see and type `{var1}`; templates are stored as `{{1}}`.
export const toDisplayVars = text => text.replace(/{{(\d+)}}/g, '{var$1}');
export const toStorageVars = text => text.replace(/{var(\d+)}/g, '{{$1}}');

export function mapStrings(value, fn) {
  if (typeof value === 'string') return fn(value);
  if (Array.isArray(value)) return value.map(item => mapStrings(item, fn));
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, val]) => [key, mapStrings(val, fn)])
    );
  }
  return value;
}

export function templatePreviewText(content, category) {
  return toDisplayVars(
    collectTemplateTexts(content, category).find(Boolean) || ''
  );
}

export function extractVariableKeys(texts) {
  const matches = texts
    .filter(Boolean)
    .flatMap(text => text.match(/{{([^}]+)}}/g) || []);
  return [...new Set(matches.map(match => match.replace(/[{}]/g, '').trim()))];
}

export function renderTemplateText(text, values) {
  if (!text) return text;
  return text.replace(
    /{{([^}]+)}}/g,
    (match, key) => values[key.trim()] || toDisplayVars(match)
  );
}
