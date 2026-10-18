const translatedEntityValues: Record<string, string> = {
  "&quot;": '"',
  "&#39;": "'",
  "&amp;": "&",
  "&lt;": "<",
  "&gt;": ">",
};

export function decodeTranslatedText(value: string): string {
  return value.replace(
    /&(quot|#39|amp|lt|gt);/g,
    (entity) => translatedEntityValues[entity] ?? entity,
  );
}
