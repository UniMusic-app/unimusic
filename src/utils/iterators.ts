export async function* raceIterators<T>(
	iteratorsIterable: Iterable<AsyncIterator<T>>,
): AsyncGenerator<T> {
	type Item = [AsyncIterator<T>, IteratorResult<T>?, Promise<Item>?];

	const iteratorStack = [...iteratorsIterable];
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
