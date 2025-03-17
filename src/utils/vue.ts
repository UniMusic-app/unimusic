import { MaybeRefOrGetter } from "@vueuse/core";
import { useIDBKeyval, UseIDBOptions } from "@vueuse/integrations/useIDBKeyval";
import { computed, onMounted, ref, Ref, watch } from "vue";

export async function useIDBKeyvalAsync<T>(
	key: IDBValidKey,
	initialValue: MaybeRefOrGetter<T>,
	options?: UseIDBOptions,
): Promise<Ref<T>> {
	const idbKeyval = useIDBKeyval<T>(key, initialValue, options);

	if (!idbKeyval.isFinished) {
		await new Promise<void>((resolve) => {
			const unwatch = watch(idbKeyval.isFinished, (isFinished) => {
				if (isFinished) {
					unwatch();
					resolve();
				}
			});
		});
	}

	return idbKeyval.data;
}

export function usePresentingElement(): Ref<HTMLElement | undefined> {
	const presentingElement = ref();

	onMounted(() => {
		presentingElement.value = document.querySelector("ion-router-outlet");
	});

	return presentingElement;
}

interface UseLoadingCounter {
	loadingCounter: Ref<number>;
	loading: Ref<boolean>;
	onLoad(): Promise<void>;
}

export function useLoadingCounter(): UseLoadingCounter {
	const loadPromises: PromiseWithResolvers<void>[] = [];

	const loadingCounter = ref(0);
	const loading = computed({
		get() {
			return loadingCounter.value > 0;
		},
		set(value) {
			if (value) {
				loadingCounter.value += 1;
			} else {
				loadingCounter.value = Math.max(0, loadingCounter.value - 1);
				loadPromises.pop()?.resolve();
			}
		},
	});

	/** Returns a promise which resolves on most recent counter decrement */
	function onLoad(): Promise<void> {
		const promise = Promise.withResolvers<void>();
		loadPromises.push(promise);
		return promise.promise;
	}

	return { loadingCounter, loading, onLoad };
}
