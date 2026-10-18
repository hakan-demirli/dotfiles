import type {
  ExtensionAPI,
  ExtensionContext,
  ReadonlyFooterDataProvider,
  Theme,
  ThemeColor,
} from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

type TokenTotals = {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
};

type Stats = TokenTotals & {
  key: string;
  cacheHitRate: number | undefined;
};

const formatTokens = (count: number): string => {
  if (count < 1000) return `${count}`;
  if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
  if (count < 1000000) return `${Math.round(count / 1000)}k`;
  if (count < 10000000) return `${(count / 1000000).toFixed(1)}M`;
  return `${Math.round(count / 1000000)}M`;
};

const formatHomePath = (path: string): string => {
  const home = process.env.HOME ?? process.env.USERPROFILE;
  if (!home) return path;
  if (path === home) return "~";
  return path.startsWith(`${home}/`) ? `~${path.slice(home.length)}` : path;
};

const addUsage = (totals: TokenTotals, usage: TokenTotals | undefined): void => {
  if (!usage) return;
  totals.input += usage.input;
  totals.output += usage.output;
  totals.cacheRead += usage.cacheRead;
  totals.cacheWrite += usage.cacheWrite;
};

const cacheHitRateOf = (usage: TokenTotals): number | undefined => {
  const prompt = usage.input + usage.cacheRead + usage.cacheWrite;
  if (prompt <= 0) return undefined;
  return (usage.cacheRead / prompt) * 100;
};

const collectStats = (ctx: ExtensionContext, cached: Stats | undefined): Stats => {
  const entries = ctx.sessionManager.getEntries();
  const key = [ctx.sessionManager.getSessionId(), ctx.sessionManager.getLeafId(), entries.length, ctx.model?.id ?? ""].join(":");
  if (cached && cached.key === key) return cached;

  const totals: TokenTotals = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };
  let cacheHitRate: number | undefined;

  for (const entry of entries) {
    if (entry.type === "usage") {
      addUsage(totals, entry.usage);
      continue;
    }

    if (entry.type === "message") {
      const message = entry.message;
      if (message.role === "assistant") {
        addUsage(totals, message.usage);
        const rate = cacheHitRateOf(message.usage);
        if (rate !== undefined) cacheHitRate = rate;
      } else if (message.role === "toolResult") {
        addUsage(totals, message.usage);
      }
      continue;
    }

    if (entry.type === "branch_summary" || entry.type === "compaction") {
      addUsage(totals, entry.usage);
    }
  }

  return { key, ...totals, cacheHitRate };
};

const cacheHitColor = (rate: number): ThemeColor => (rate >= 90 ? "success" : rate >= 50 ? "muted" : "warning");

const contextColor = (percent: number | null): ThemeColor =>
  percent === null ? "muted" : percent > 90 ? "error" : percent > 70 ? "warning" : "muted";

const sanitizeStatus = (text: string): string => text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim();

export function buildFooter(ctx: ExtensionContext, theme: Theme, footerData: ReadonlyFooterDataProvider) {
  let stats: Stats | undefined;

  const stat = (label: string, value: string, color: ThemeColor) => `${theme.fg("dim", label)} ${theme.fg(color, value)}`;

  return {
    invalidate(): void {
      stats = undefined;
    },

    render(width: number): string[] {
      stats = collectStats(ctx, stats);

      const lead: string[] = [];
      if (stats.input > 0) lead.push(stat("↑", formatTokens(stats.input), "muted"));
      if (stats.output > 0) lead.push(stat("↓", formatTokens(stats.output), "muted"));

      const optional: string[] = [];
      if (stats.cacheRead > 0) optional.push(stat("R", formatTokens(stats.cacheRead), "muted"));
      if (stats.cacheWrite > 0) optional.push(stat("W", formatTokens(stats.cacheWrite), "muted"));
      if (stats.cacheHitRate !== undefined) {
        optional.push(stat("cache", `${stats.cacheHitRate.toFixed(1)}%`, cacheHitColor(stats.cacheHitRate)));
      }

      const usage = ctx.getContextUsage();
      const contextWindow = usage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
      const contextValue =
        usage?.tokens === null || usage === undefined
          ? `?/${formatTokens(contextWindow)}`
          : `${formatTokens(usage.tokens)}/${formatTokens(contextWindow)}`;
      const tail = [stat("ctx", contextValue, contextColor(usage?.percent ?? null))];

      const model = ctx.model;
      let right = model?.id ?? "no-model";
      if (model?.reasoning) {
        const level = ctx.thinkingLevel ?? "off";
        right += level === "off" ? " • thinking off" : ` • ${level}`;
      }

      const separator = theme.fg("dim", "  ·  ");
      const full = [...lead, ...optional, ...tail].join(separator);
      const compact = [...lead, ...tail].join(separator);
      const modelWidth = visibleWidth(right) + 2;
      const left = visibleWidth(full) + modelWidth <= width ? full : visibleWidth(compact) + modelWidth <= width ? compact : full;
      const leftWidth = visibleWidth(left);

      const rightBudget = width - leftWidth - 2;
      let rightSide = right;
      if (model && footerData.getAvailableProviderCount() > 1) {
        const withProvider = `(${model.provider}) ${right}`;
        if (visibleWidth(withProvider) <= rightBudget) rightSide = withProvider;
      }
      rightSide = rightBudget > 0 ? truncateToWidth(rightSide, rightBudget, "") : "";

      const branch = footerData.getGitBranch();
      const sessionName = ctx.sessionManager.getSessionName();
      const location = [formatHomePath(ctx.sessionManager.getCwd()), branch && `(${branch})`, sessionName]
        .filter(Boolean)
        .join(" • ");

      const lines = [
        truncateToWidth(theme.fg("dim", location), width, theme.fg("dim", "...")),
        truncateToWidth(
          `${left}${" ".repeat(Math.max(0, width - leftWidth - visibleWidth(rightSide)))}${theme.fg("muted", rightSide)}`,
          width,
          theme.fg("dim", "..."),
        ),
      ];

      const statuses = Array.from(footerData.getExtensionStatuses().values())
        .map(sanitizeStatus)
        .filter(Boolean);
      if (statuses.length > 0) {
        lines.push(truncateToWidth(theme.fg("dim", statuses.join(" ")), width, theme.fg("dim", "...")));
      }

      return lines;
    },
  };
}

export default function (pi: ExtensionAPI) {
  let custom = false;

  const enable = (ctx: ExtensionContext) => {
    if (ctx.mode !== "tui") return;
    ctx.ui.setFooter((tui, theme, footerData) => {
      const unsubscribe = footerData.onBranchChange(() => tui.requestRender());
      return { ...buildFooter(ctx, theme, footerData), dispose: unsubscribe };
    });
    custom = true;
  };

  pi.on("session_start", async (_event, ctx) => {
    enable(ctx);
  });

  pi.registerCommand("footer", {
    description: "Toggle the spaced usage footer",
    handler: async (_args, ctx) => {
      if (custom) {
        ctx.ui.setFooter(undefined);
        custom = false;
        ctx.ui.notify("Built-in footer restored", "info");
      } else {
        enable(ctx);
        ctx.ui.notify("Spaced footer enabled", "info");
      }
    },
  });
}
