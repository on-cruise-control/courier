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

export function templatePreviewText(content, category) {
  return collectTemplateTexts(content, category).find(Boolean) || '';
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
    (match, key) => values[key.trim()] || match
  );
}
