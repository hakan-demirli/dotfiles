import { readdir, readFile, realpath, stat } from "node:fs/promises";
import { dirname, join, parse } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type InstructionFile = { path: string; content: string };
type LoadedInstructions = { cwd: string; files: InstructionFile[] };

const instructionDirectories = [".agent", join(".hydrate", "agent")];

async function optional<T>(operation: () => Promise<T>): Promise<T | undefined> {
  try {
    return await operation();
  } catch (error) {
    if (
      error instanceof Error &&
      "code" in error &&
      (error.code === "ENOENT" || error.code === "ENOTDIR")
    ) {
      return undefined;
    }
    throw error;
  }
}

export default function (pi: ExtensionAPI) {
  let loaded: LoadedInstructions | undefined;

  async function load(cwd: string): Promise<LoadedInstructions> {
    const start = await realpath(cwd);
    const git = await pi.exec("git", ["-C", start, "rev-parse", "--show-toplevel"], {
      timeout: 5000,
    });
    const root = git.code === 0 ? await realpath(git.stdout.trim()) : parse(start).root;
    const ancestors: string[] = [];
    for (let directory = start; ; directory = dirname(directory)) {
      ancestors.push(directory);
      if (directory === root || dirname(directory) === directory) break;
    }

    const files: InstructionFile[] = [];
    const seen = new Set<string>();
    for (const relativeDirectory of instructionDirectories) {
      for (const ancestor of ancestors) {
        const directory = join(ancestor, relativeDirectory);
        const names = await optional(() => readdir(directory));
        for (const name of (names ?? []).filter((name) => name.endsWith(".md")).sort()) {
          const path = await optional(() => realpath(join(directory, name)));
          if (!path || seen.has(path)) continue;
          const info = await optional(() => stat(path));
          if (!info?.isFile()) continue;
          const content = await optional(() => readFile(path, "utf8"));
          if (content === undefined) continue;
          seen.add(path);
          files.push({ path, content: content.replace(/^\uFEFF/, "") });
        }
      }
    }
    return { cwd, files };
  }

  pi.on("session_start", async (_event, ctx) => {
    loaded = undefined;
    loaded = await load(ctx.cwd);
  });

  pi.on("before_agent_start", async (event, ctx) => {
    if (loaded?.cwd !== ctx.cwd) loaded = await load(ctx.cwd);
    const contextFiles = event.systemPromptOptions.contextFiles;
    const seen = new Set(
      await Promise.all(
        contextFiles.map(async (file) => (await optional(() => realpath(file.path))) ?? file.path),
      ),
    );
    for (const file of loaded.files) {
      if (seen.has(file.path)) continue;
      seen.add(file.path);
      contextFiles.push(file);
    }
  });
}
