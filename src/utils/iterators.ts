export async function* racedPromisesIterator<T extends Promise<unknown>>(
	promises: Iterable<T>,
): AsyncGenerator<Awaited<T>> {
	const pending = new Set(promises);
	for (const promise of pending) {
		void promise.finally(() => pending.delete(promise));
	}
	while (pending.size) yield await Promise.race<T>(pending);
}

export async function* racedIterators<T>(
	iteratorsIterable: Iterable<AsyncIterator<T>>,
): AsyncGenerator<T> {
	type Item = [AsyncIterator<T>, IteratorResult<T>?, Promise<Item>?];

	const iteratorStack = [...iteratorsIterable];
	if (!iteratorStack.length) return;
	const promises = new Set<Promise<Item>>();

	do {
		let iterator: AsyncIterator<T> | undefined;
		while ((iterator = iteratorStack.pop())) {
			const next = iterator.next();
			const item: Item = [iterator];
			const promise: Promise<Item> = next.then((result) => {
				item[1] = result;
				return item;
			});
			item[2] = promise;

			promises.add(promise);
		}

		const [resultIterator, result, promise] = await Promise.race(promises);
		promises.delete(promise!);
		if (!result?.done) {
			yield result!.value;
			iteratorStack.push(resultIterator);
		}
	} while (iteratorStack.length || promises.size);
}

const ABORTABLE_GENERATOR_RETURN_REASON = Symbol.for("AbortableAsyncGenerator.ReturnReason");
export function abortableAsyncGenerator<T>(
	generator: Generator<T> | AsyncGenerator<T>,
	controller = new AbortController(),
): AsyncGenerator<T> {
	const { promise, resolve, reject } = Promise.withResolvers<IteratorResult<T>>();

	controller.signal.addEventListener("abort", () => {
		if (controller.signal.reason !== ABORTABLE_GENERATOR_RETURN_REASON) {
			reject(controller.signal.reason);
		}
	});

	const abortable: AsyncGenerator<T> = {
		async next() {
			return await Promise.race([promise, generator.next()]);
		},
		async return(value) {
			if (!controller.signal.aborted) {
				controller.abort(ABORTABLE_GENERATOR_RETURN_REASON);
				resolve({ done: true, value });
				await generator.return(value);
			}
			return promise;
		},
		async throw(error) {
			if (!controller.signal.aborted) {
				controller.abort(error);
				reject(error);
				await generator.throw(error);
			}
			return promise;
		},

		[Symbol.asyncIterator]() {
			return abortable;
		},
		async [Symbol.asyncDispose]() {
			if (Symbol.asyncDispose in generator) {
				await generator?.[Symbol.asyncDispose]();
			} else {
				generator[Symbol.dispose]();
			}
		},
	};

	return abortable;
}

/**
 * Iterator.take which doesn't automatically close the underlying iterator
 */
export async function* take<T>(iterator: AsyncIterator<T>, n: number): AsyncGenerator<T> {
	for (let i = 0; i < n; ++i) {
		const result = await iterator.next();
		if (result.done) return;
		yield result.value;
	}
}
