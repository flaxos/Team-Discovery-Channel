class RequestError extends Error {
  constructor(message, status = 400) { super(message); this.status = status; }
}
const invalid = message => { throw new RequestError(message); };
function fields(body, allowed = []) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) invalid('A JSON object is required.');
  for (const key of Object.keys(body)) if (!allowed.includes(key)) invalid(`Unexpected field: ${key}`);
  return body;
}
function text(value, label, max = 200, { optional = false, empty = false } = {}) {
  if (value === undefined && optional) return undefined;
  if (typeof value !== 'string' || value.length > max || (!empty && !value.trim()) || /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(value)) invalid(`Invalid ${label}.`);
  return value.trim();
}
function id(value, label = 'ID') {
  if (typeof value !== 'string' || !/^[a-zA-Z0-9][a-zA-Z0-9_-]{0,79}$/.test(value) || ['constructor', 'prototype', '__proto__'].includes(value)) invalid(`Invalid ${label}.`);
  return value;
}
function stringList(value, label, maxItems = 20, maxLength = 200) {
  if (!Array.isArray(value) || value.length > maxItems) invalid(`Invalid ${label}.`);
  return value.map(item => text(item, label, maxLength));
}
function boolean(value, label, fallback = false) {
  if (value === undefined) return fallback;
  if (typeof value !== 'boolean') invalid(`Invalid ${label}.`);
  return value;
}
function findQuestion(state, value) {
  const item = state.questions.find(item => item.id === id(value, 'question ID'));
  if (!item) throw new RequestError('Question not found.', 404);
  return item;
}
function findMember(state, value) {
  const item = state.team.find(item => item.id === id(value, 'member ID'));
  if (!item) throw new RequestError('Member not found.', 404);
  return item;
}
function findOption(question, value) {
  const item = question.options.find(item => item.id === id(value, 'option ID'));
  if (!item) throw new RequestError('Option not found.', 404);
  return item;
}
module.exports = { RequestError, invalid, fields, text, id, stringList, boolean, findQuestion, findMember, findOption };
