import type {
  ExtensionAPI,
  MarkdownTransformer,
} from "@earendil-works/pi-coding-agent";

const fenceMarker = /^(\s*)(`{3,}|~{3,})(.*)$/;

const blockMarkers = /^(\s*)(#{1,6}\s|>\s?|[-+*]\s|\d+[.)]\s)/;

const escapeBlockMarker = (line: string): string =>
  blockMarkers.test(line) ? line.replace(blockMarkers, "$1\\$2") : line;

export const demoteThinkingCodeFences = (markdown: string): string => {
  const lines = markdown.split("\n");
  const transformed: string[] = [];
  let fence: string | undefined;

  for (const line of lines) {
    const match = fenceMarker.exec(line);

    if (fence === undefined) {
      if (match) {
        fence = match[2];
        continue;
      }
      transformed.push(line);
      continue;
    }

    if (match && match[2].length >= fence.length && match[3].trim() === "") {
      fence = undefined;
      continue;
    }

    transformed.push(`> ${line === "" ? "" : escapeBlockMarker(line)}`);
  }

  return transformed.join("\n");
};

const transformer: MarkdownTransformer = (markdown, context) =>
  context.messageType === "assistant-thinking"
    ? demoteThinkingCodeFences(markdown)
    : markdown;

export default function (pi: ExtensionAPI) {
  pi.registerMarkdownTransformer(transformer);
}
