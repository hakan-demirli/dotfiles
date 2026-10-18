import { getMarkdownTheme, type ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Key, Markdown, matchesKey, truncateToWidth } from "@mariozechner/pi-tui";

type AssistantText = {
	text: string;
	entryId?: string;
};

function getLastAssistantText(ctx: { sessionManager: { getBranch(): any[] } }): AssistantText | undefined {
	const branch = ctx.sessionManager.getBranch();

	for (let i = branch.length - 1; i >= 0; i--) {
		const entry = branch[i];
		if (entry?.type !== "message") continue;
		const message = entry.message;
		if (!message || message.role !== "assistant") continue;

		const parts = Array.isArray(message.content)
			? message.content
					.filter((part: any): part is { type: "text"; text: string } => part?.type === "text" && typeof part.text === "string")
					.map((part: { text: string }) => part.text.trim())
					.filter(Boolean)
			: [];

		if (parts.length === 0) continue;
		return { text: parts.join("\n\n"), entryId: entry.id };
	}

	return undefined;
}

class HeadViewer {
	private scroll = 0;
	private cachedWidth = -1;
	private cachedLines: string[] = [];
	private markdown: Markdown;

	constructor(
		private readonly text: string,
		private readonly entryId: string | undefined,
		private readonly tui: { terminal: { rows: number }; requestRender(): void },
		private readonly theme: any,
		private readonly close: () => void,
	) {
		this.markdown = new Markdown(this.text, 1, 0, getMarkdownTheme());
	}

	handleInput(data: string): void {
		const page = this.pageSize();
		let handled = true;

		if (matchesKey(data, Key.escape) || data === "q") {
			this.close();
			return;
		} else if (matchesKey(data, Key.down) || data === "j") {
			this.scroll += 1;
		} else if (matchesKey(data, Key.up) || data === "k") {
			this.scroll -= 1;
		} else if (matchesKey(data, Key.pageDown) || data === " " || data === "f") {
			this.scroll += page;
		} else if (matchesKey(data, Key.pageUp) || data === "b") {
			this.scroll -= page;
		} else if (matchesKey(data, Key.home) || data === "g") {
			this.scroll = 0;
		} else if (matchesKey(data, Key.end) || data === "G") {
			this.scroll = Number.MAX_SAFE_INTEGER;
		} else {
			handled = false;
		}

		if (handled) {
			this.clampScroll();
			this.tui.requestRender();
		}
	}

	render(width: number): string[] {
		if (this.cachedWidth !== width) {
			this.markdown = new Markdown(this.text, 1, 0, getMarkdownTheme());
			this.cachedLines = this.markdown.render(width);
			this.cachedWidth = width;
			this.clampScroll();
		}

		const page = this.pageSize();
		const total = this.cachedLines.length;
		const visible = this.cachedLines.slice(this.scroll, this.scroll + page);
		while (visible.length < page) visible.push("");

		const headerLabel = this.entryId ? ` /head — last assistant response (${this.entryId.slice(0, 8)}) ` : " /head — last assistant response ";
		const scrollLabel = total > 0 ? ` lines ${Math.min(this.scroll + 1, total)}-${Math.min(this.scroll + page, total)} / ${total} ` : " no content ";
		const top = this.borderWithLabel(width, headerLabel, "accent");
		const bottom = this.borderWithLabel(width, scrollLabel, "muted");
		const help = " ↑/k ↓/j PgUp/b PgDn/space/f g/G top/bottom q/Esc close ";

		return [
			top,
			...visible.map((line) => truncateToWidth(line, width, "")),
			bottom,
			truncateToWidth(this.theme.fg("dim", help), width, ""),
		];
	}

	invalidate(): void {
		this.cachedWidth = -1;
		this.cachedLines = [];
		this.markdown.invalidate();
	}

	private pageSize(): number {
		return Math.max(5, this.tui.terminal.rows - 6);
	}

	private clampScroll(): void {
		const max = Math.max(0, this.cachedLines.length - this.pageSize());
		this.scroll = Math.max(0, Math.min(this.scroll, max));
	}

	private borderWithLabel(width: number, label: string, color: "accent" | "muted"): string {
		if (width <= 0) return "";
		if (width <= label.length + 2) return this.theme.fg(color, "─".repeat(width));
		const left = Math.floor((width - label.length) / 2);
		const right = Math.max(0, width - label.length - left);
		return this.theme.fg(color, `${"─".repeat(left)}${label}${"─".repeat(right)}`);
	}
}

export default function headExtension(pi: ExtensionAPI) {
	pi.registerCommand("head", {
		description: "Open the last assistant response from its first line with keyboard scrolling",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) {
				ctx.ui.notify("/head requires interactive mode", "error");
				return;
			}

			const found = getLastAssistantText(ctx);
			if (!found) {
				ctx.ui.notify("No assistant response found", "warning");
				return;
			}

			await ctx.ui.custom<void>(
				(tui, theme, _keybindings, done) => {
					const container = new HeadViewer(found.text, found.entryId, tui, theme, () => done(undefined));
					return container;
				},
				{
					overlay: true,
					overlayOptions: {
						anchor: "top-left",
						width: "100%",
						maxHeight: "100%",
					},
				},
			);
		},
	});
}
