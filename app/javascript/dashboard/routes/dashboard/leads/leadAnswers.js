const humanize = key =>
  key.charAt(0).toUpperCase() + key.slice(1).replace(/_/g, ' ');

// Answered questions only, labelled with the question text from the form definition
export const buildLeadAnswers = (lead, questions = []) =>
  lead.field_data
    .map(field => ({
      key: field.name,
      label:
        questions.find(question => question.key === field.name)?.label ||
        humanize(field.name),
      value: (field.values || []).join(', ').trim(),
    }))
    .filter(answer => answer.value && answer.key !== 'inbox_url');
