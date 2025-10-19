export function generateSearchKeywords(name: string): string[] {
  const normalized = name
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .filter(Boolean);

  const keywords = new Set<string>();

  normalized.forEach((token) => {
    keywords.add(token);
  });

  const phrase = normalized.join(" ");
  if (phrase) {
    keywords.add(phrase);
  }

  return Array.from(keywords);
}
