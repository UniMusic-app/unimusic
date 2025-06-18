interface PromiseCallback<T> {
	(): Promise<T>;
}

interface PromiseRequest<T> {
	promise: PromiseWithResolvers<T>;
	callback: PromiseCallback<T>;
}

export class PromiseQueue<T> {
	queue: PromiseRequest<T>[] = [];
	polling = false;

	constructor() {}

	async push(callback: PromiseCallback<T>): Promise<T> {
		const promise = Promise.withResolvers<T>();

		this.queue.push({ promise, callback });
		if (!this.polling) void this.#poll();

		return await promise.promise;
	}

	#poll(): void {
		if (!this.queue.length) {
			this.polling = false;
			return;
		}
		this.polling = true;

		const { promise, callback } = this.queue.shift()!;

		callback()
			.then(promise.resolve)
			.catch(promise.reject)
			.finally(() => this.#poll());
	}
}
