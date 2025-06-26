import { Service } from "@/services/Service";
import { LocalImage } from "@/stores/local-images";
import { Maybe } from "@/utils/types";
import { computed, ref } from "vue";

export interface Metadata {
	isrc?: string[];

	title?: string;
	album?: string;
	artists?: { id?: string; title: string }[];
	genres?: string[];

	duration?: number;
	artwork?: LocalImage;

	discNumber?: number;
	trackNumber?: number;
}

export interface MetadataLookup {
	id: string;

	title?: string;
	album?: string;
	artists?: string[];
	duration?: number;
	isrc?: string;

	filePath?: string;
}

export interface MetadataServiceState {
	enabled: boolean;
	order: number;
}

export abstract class MetadataService extends Service<MetadataServiceState> {
	abstract name: string;
	abstract logName: string;
	abstract available: boolean;
	abstract description: string;

	#order = ref(0);
	order = computed({
		get: () => this.#order.value,
		set: async (value) => {
			await this.reorder(value);
		},
	});

	#enabled = ref(false);
	enabled = computed({
		get: () => {
			const enabled = this.#enabled.value;
			return this.available && enabled;
		},
		set: async (value) => {
			if (value) {
				await this.enable();
			} else {
				await this.disable();
			}
		},
	});

	constructor() {
		super();
		// Execute restoreState after the whole class has been instantiated
		queueMicrotask(() => void this.restoreState());
	}

	async reorder(value: number): Promise<void> {
		this.log("reorder", value);
		this.#order.value = value;
		console.log(await this.getSavedState());
		await this.saveState({
			enabled: this.#enabled.value,
			order: value,
		});
		console.log(await this.getSavedState());
	}

	async enable(): Promise<void> {
		this.log("enable");
		this.#enabled.value = true;
		await this.saveState({
			enabled: true,
			order: this.order.value,
		});
	}

	async disable(): Promise<void> {
		this.log("disable");
		this.#enabled.value = false;
		await this.saveState({
			enabled: false,
			order: this.order.value,
		});
	}

	async restoreState(): Promise<void> {
		if (!this.available) return;

		this.log("restoreState");
		const state = await this.getSavedState();
		if (!state) return;

		this.#enabled.value = state.enabled;
		this.#order.value = state.order;
	}

	abstract handleGetMetadata(lookup: MetadataLookup): Maybe<Metadata> | Promise<Maybe<Metadata>>;
	async getMetadata(lookup: MetadataLookup): Promise<Maybe<Metadata>> {
		this.log("getMetadata");

		const metadata = await this.handleGetMetadata(lookup);
		return metadata;
	}
}
