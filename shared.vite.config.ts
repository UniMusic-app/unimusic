import path from "path";
import type { BuildEnvironmentOptions } from "vite";

function parseBoolVar(value: string | boolean): boolean {
	if (typeof value === "boolean") return value;
	return !!JSON.parse(value);
}

export const sharedDefine = {
	__SERVICE_LOCAL__: parseBoolVar(process.env.SERVICE_LOCAL ?? true),
	__SERVICE_YOUTUBE__: parseBoolVar(process.env.SERVICE_YOUTUBE ?? true),
	__SERVICE_MUSICKIT__: parseBoolVar(process.env.SERVICE_MUSICKIT ?? true),
};

export const sharedBuild: BuildEnvironmentOptions = {
	sourcemap: "inline",
};

export const sharedAlias = {
	"@": path.resolve(__dirname, "./src"),
};
