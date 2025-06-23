import { WebPlugin } from "@capacitor/core";
import { ChromaprintPlugin } from "../Chromaprint";

import { processAudioFile } from "@unimusic/chromaprint";

import { getFileStream } from "@/utils/path";
import { PromiseQueue } from "@/utils/promise-queue";
import { sleep } from "@/utils/time";

const fingerprintQueue = new PromiseQueue<string>();

// Web implementation of Chromaprint
export class Chromaprint extends WebPlugin implements ChromaprintPlugin {
	async fingerprint(options: { filePath: string }): Promise<{ fingerprint: string }> {
		const fileStream = await getFileStream(options.filePath);
		const fileBuffer = await new Response(fileStream).arrayBuffer();

		const fingerprint = await fingerprintQueue.push(async () => {
			const [fingerprint] = await Array.fromAsync(processAudioFile(fileBuffer));
			// This delay is necessary, because for whatever reason chrome can just crash
			// If files are decoded in quick succession
			await sleep(1000);
			return fingerprint!;
		});

		return { fingerprint };
	}
}
