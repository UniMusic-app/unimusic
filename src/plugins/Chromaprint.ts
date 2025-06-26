import { registerPlugin } from "@capacitor/core";

export interface ChromaprintPlugin {
	fingerprint(options: { filePath: string }): Promise<{ fingerprint: string }>;
}

async function webImplementation(): Promise<
	InstanceType<typeof import("./Chromaprint/web").Chromaprint>
> {
	const { Chromaprint } = await import("./Chromaprint/web");
	return new Chromaprint();
}

const Chromaprint = registerPlugin<ChromaprintPlugin>("Chromaprint", {
	web: webImplementation,
	android: webImplementation,
});

export default Chromaprint;
