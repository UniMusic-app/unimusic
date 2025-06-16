export interface RateLimits {
	[domain: string]: number;
}

interface RateLimitRequest {
	url: URL;
	init?: RequestInit;
	promise: PromiseWithResolvers<Response>;
}

export interface RateLimitData {
	[domain: string]: {
		polling: boolean;
		lastCall: number;
		queue: RateLimitRequest[];
	};
}

export class RateLimiter {
	rateLimits: RateLimits;
	data: RateLimitData;

	constructor(rateLimits: RateLimits) {
		this.rateLimits = rateLimits;
		this.data = {};
	}

	async fetch(url: URL, init?: RequestInit): Promise<Response> {
		const domain = url.hostname;
		const data = (this.data[domain] ??= { polling: false, lastCall: 0, queue: [] });

		const promise = Promise.withResolvers<Response>();

		data.queue.push({ url, init, promise });
		if (!data.polling) this.#poll(domain);

		return await promise.promise;
	}

	#poll(domain: string): void {
		const data = this.data[domain]!;
		if (!data.queue.length) {
			data.polling = false;
			return;
		}
		data.polling = true;

		const rateLimit = this.rateLimits[domain];
		if (!rateLimit) throw new Error(`No limits set for domain: ${domain}`);

		const deltaTime = Date.now() - data.lastCall;
		if (deltaTime < rateLimit) {
			setTimeout(() => this.#poll(domain), rateLimit - deltaTime);
		} else {
			const request = data.queue.shift()!;
			data.lastCall = Date.now();
			void this.#fetch(request);
			this.#poll(request.url.hostname);
		}
	}

	async #fetch(request: RateLimitRequest): Promise<void> {
		try {
			const response = await fetch(request.url, request.init);
			request.promise.resolve(response);
		} catch (error) {
			request.promise.reject(error);
		}
	}
}
